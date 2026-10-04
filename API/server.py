import asyncio
import json
import uvicorn
from typing import Annotated
from fastapi import FastAPI, Depends, HTTPException, status, Response, Request, Header
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from location import nearby_search, place_details, find_autocomplete, meal_availability
from auth import (authenticate_user, create_access_token, get_current_active_user, fake_users_db, ACCESS_TOKEN_EXPIRE_MINUTES, get_password_hash, decode_token, token_validation, get_user)
from database import DBUser, get_db, DBUserDinedRestaurants, DBRestaurant, DBReviews, DBQueries, DBQueriedRestaurants, DBUserPreferences, DBWantToGo
from recommendation import RecommendationMap, PartyRecommendation
from models import User, UserCreate, UserForm, UserInformation, VisitedRestaurant, PickLocation, RestaurantRating, Autocomplete, Hours, Recommend, Preferences, WantToGo
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from pick_location import geocode
from cuisines import CUISINES, parse_tastes
from geopy.distance import geodesic
from sqlalchemy import func

app = FastAPI(title="Authentication Demo", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])


def _restaurant_with_flags(place_id, name, hours_json):
    """Rebuild a restaurant's meal flags from its stored opening-hours JSON."""
    periods = json.loads(hours_json) if hours_json else []
    return {"id": place_id, "name": name, **meal_availability(periods)}

def _save_restaurants(db, data):
    """Store nearby_search results so /recommend can find them. Returns the DB rows; caller commits."""
    db_restaurants = []
    for restaurant in data:
        place_id = restaurant["id"]
        hours_json = json.dumps(restaurant["hours"])

        db_restaurant = db.query(DBRestaurant).filter(DBRestaurant.place_id == place_id).first()
        if db_restaurant is None:
            db_restaurant = DBRestaurant(place_id=place_id, name=restaurant["name"], hours=hours_json)
            db.add(db_restaurant)
            db.flush()
        elif db_restaurant.hours is None:
            db_restaurant.hours = hours_json
        # Older rows were saved before we asked Google for these
        if db_restaurant.location is None:
            db_restaurant.location = json.dumps(restaurant["location"])
        if not db_restaurant.primary_type:
            db_restaurant.primary_type = restaurant["primary_type"]
        db_restaurants.append(db_restaurant)
    return db_restaurants

def _restaurant_list(db, db_restaurants, lat, lng):
    """What the app's restaurant list needs: meal flags, map position, distance from the search center, and our users' average rating."""
    ids = [r.id for r in db_restaurants]
    stats = {
        restaurant_id: (average, count)
        for restaurant_id, average, count in db.query(
            DBReviews.restaurant_id, func.avg(DBReviews.rating), func.count(DBReviews.id)
        ).filter(DBReviews.restaurant_id.in_(ids)).group_by(DBReviews.restaurant_id).all()
    }
    results = []
    for r in db_restaurants:
        item = _restaurant_with_flags(r.place_id, r.name, r.hours)
        location = json.loads(r.location) if r.location else None
        average, count = stats.get(r.id, (None, 0))
        item.update({
            "lat": location[0] if location else None,
            "lng": location[1] if location else None,
            "distance": geodesic((lat, lng), location).miles if location else None,
            "average_rating": round(float(average), 1) if average is not None else None,
            "review_count": count,
            "hours": json.loads(r.hours) if r.hours else [],
        })
        results.append(item)
    return results

def _get_db_user(db, current_user):
    return db.query(DBUser).filter(DBUser.username == current_user.username).first()

def _user_tastes(db, user_id):
    """The user's taste profile as {cuisine_key: score}."""
    prefs = db.query(DBUserPreferences).filter(DBUserPreferences.id == user_id).first()
    return parse_tastes(prefs.food_preferences) if prefs else {}

def _taste_list(tastes):
    """{key: score} -> [{"key", "score"}] in CUISINES order, the shape the app decodes."""
    return [{"key": key, "score": tastes[key]} for key in CUISINES if key in tastes]

@app.post("/visited_restaurants")
async def visited_restaurants(body: VisitedRestaurant, user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    db_user = db.query(DBUser).filter(DBUser.username == user.username).first()
    db_place = db.query(DBRestaurant).filter(DBRestaurant.place_id == body.place_id).first()
    if db_place is None or db_place.hours is None:
        details = await place_details(body.place_id, 0, 0)
        if db_place is None:
            db_place = DBRestaurant(place_id=body.place_id, name=details["name"])
            db.add(db_place)
        db_place.hours = json.dumps(details["current_opening_hours"])
        db_place.location = json.dumps(details["location"])
        if not db_place.primary_type:
            db_place.primary_type = details["primary_type"]
        db.commit()
        db.refresh(db_place)
    try:
        db.add(DBUserDinedRestaurants(user_id=db_user.id, restaurant_id=db_place.id, date_visited= body.date_visited))
        db.commit()
    except IntegrityError:
        db.rollback()
       # required — the session is broken after the failed insert
    return db_place

    



@app.get("/restaurant_details/{restaurant_id}")
async def restaurant_details(restaurant_id: str, current_user: User = Depends(get_current_active_user), lat: float = 0.0, lng: float = 0.0):

    return await place_details(restaurant_id, lat, lng)

@app.post("/pick_location")
async def pick_location(body:PickLocation, user = Depends(get_current_active_user), db: Session = Depends(get_db)):
    response = geocode(body.address)
    if response is None:
        raise HTTPException(status_code=404, detail="Address not found")
    # Nominatim returns coordinates as strings
    lat = float(response["lat"])
    lng = float(response["lon"])
    data = await nearby_search(lat, lng, body.radius*1609.344)
    db_restaurants = _save_restaurants(db, data)
    db.commit()
    return {"lat": lat, "lng": lng, "restaurants": _restaurant_list(db, db_restaurants, lat, lng)}

@app.post("/post_review")
async def rate_restaurant( restaurant_rating: RestaurantRating, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    
    place_id = restaurant_rating.place_id
    db_restaurant = db.query(DBRestaurant).filter(DBRestaurant.place_id == place_id).first()
    if db_restaurant is None:
        details = await place_details(place_id, 0, 0)
        db_restaurant = DBRestaurant(place_id=place_id, name=details["name"], primary_type=details["primary_type"])
        db.add(db_restaurant)
        db.commit()
        db.refresh(db_restaurant)
    rating = restaurant_rating.rating
    content = restaurant_rating.content
    db_user = db.query(DBUser).filter(DBUser.username == current_user.username).first()
    # db_reviews= db.query(DBReviews)
    db_review = DBReviews(
        restaurant_id = db_restaurant.id,
        reviewer_name =current_user.username,
        reviewer_id=db_user.id,
        content = content,
        rating = rating)
        
    db.add(db_review)
    db.commit()
    db.refresh(db_review)
    return {"id": db_review.id, "restaurant_id": db_review.restaurant_id, "reviewer_name": db_review.reviewer_name,"reviewer_id": db_review.reviewer_id,"content": content, "rating": db_review.rating}

@app.get("/get_reviews")
async def get_reviews(restaurant_id: str, db:Session = Depends(get_db)):
    #returns rating, reviews
    db_restaurant = db.query(DBRestaurant).filter(DBRestaurant.place_id == restaurant_id).first()
    if db_restaurant is None:
        return []  # never stored this restaurant, so it has no reviews yet

    reviews = db.query(DBReviews).filter(DBReviews.restaurant_id == db_restaurant.id)
    return reviews.all()


@app.post("/autocomplete")
async def autocomplete(data: Autocomplete):
    return await find_autocomplete(data.text)

@app.post("/find_restaurants")
async def find_restaurants(user_information: UserInformation, response: Response ,current_user: User = Depends(get_current_active_user), db:Session = Depends(get_db)):
     
    lat = user_information.lat
    lng = user_information.lng
    radius = user_information.radius*1609.344
    time = user_information.time

    db_query = db.query(DBQueries).filter(
        DBQueries.radius == radius,
        DBQueries.lat == lat,
        DBQueries.lng == lng,
    ).first()

    if db_query is not None:
        saved = (
            db.query(DBRestaurant)
            .join(DBQueriedRestaurants, DBQueriedRestaurants.restaurant_id == DBRestaurant.id)
            .filter(DBQueriedRestaurants.queried_id == db_query.id)
            .all()
        )
        if saved:  # only trust the cache if it actually has restaurants
            return _restaurant_list(db, saved, lat, lng)



    data = await nearby_search(lat, lng, radius)

    db_query = DBQueries(lat=lat, lng=lng, radius=radius)
    db.add(db_query)
    db.flush()

    db_restaurants = _save_restaurants(db, data)
    for db_restaurant in db_restaurants:
        db.add(DBQueriedRestaurants(queried_id=db_query.id, restaurant_id=db_restaurant.id))

    db.commit()
    return _restaurant_list(db, db_restaurants, lat, lng)
     
@app.get("/")
async def root():
    return {"message": "Welcome to FastAPI Authentication Demo"}

@app.post("/auth/refresh")
async def refresh_token(response: Response, request: Request,  db: Session = Depends(get_db)):
    """Authenticate user and return access token."""
    
    token = request.cookies.get('refresh_token')
    if token == None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    username = decode_token(token)

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": username}, expires_delta=access_token_expires
    )
    refresh_token = create_access_token(data={"sub": username}, expires_delta=timedelta(minutes=10080))
    response.set_cookie(key = "refresh_token", path = "/", httponly = True, secure = True, value = refresh_token)

    return {"access_token": access_token, "token_type": "bearer", "refresh_token": refresh_token}

@app.get('/show_visited')
async def show_visited(current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    db_user = db.query(DBUser).filter(DBUser.username == current_user.username).first()
    visited = (
    db.query(DBRestaurant, DBUserDinedRestaurants.date_visited)
    .join(DBUserDinedRestaurants, DBUserDinedRestaurants.restaurant_id == DBRestaurant.id)
    .filter(DBUserDinedRestaurants.user_id == db_user.id)
    .order_by(DBUserDinedRestaurants.date_visited)
    .all()
)
    grouped = {}
    for restaurant, date_visited in visited:
        entry = grouped.setdefault(restaurant.id, {
            "id": restaurant.id,
            "place_id": restaurant.place_id,
            "name": restaurant.name,
            "hours": restaurant.hours,
            "location": restaurant.location,
            "dates_visited": [],
        })
        if date_visited is not None:  # visits saved before dates existed have none
            entry["dates_visited"].append(date_visited)
    return list(grouped.values())

@app.get("/users/me", response_model=User)
async def read_users_me(current_user: User = Depends(get_current_active_user)):
    """Get current user information."""
    return current_user

@app.get("/protected/{name}")
# async def protected_route(current_user: User = Depends(get_current_active_user)):
#     return {"message": f"Hello {current_user.full_name}, this is a protected route!"}
async def protected_route(name: str, is_authenticated: bool = Depends(token_validation)):
    if(is_authenticated == True):
        return f"Hi {name}"
    return is_authenticated

@app.post("/auth/register")
def create_user(response: Response, user: UserCreate, db: Session = Depends(get_db)):
    existing_user = get_user(db, user.username)
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already exists")

    db_user = DBUser(
        username=user.username,
        email=user.email,
        full_name=user.full_name,
        hashed_password=get_password_hash(user.password)
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": db_user.username}, expires_delta=access_token_expires
    )
    refresh_token = create_access_token(data={"sub": db_user.username}, expires_delta=timedelta(minutes=10080))
    response.set_cookie(key = "refresh_token", path = "/", httponly = True, secure = True, value = refresh_token)

    return {"access_token": access_token, "token_type": "bearer", "refresh_token": refresh_token }


@app.post("/auth/login")
def login_user(user: UserForm, response: Response, db: Session = Depends(get_db)):
    existing_user = get_user(db, user.username)
    if not existing_user:
        raise HTTPException(status_code=404, detail="User not found")
    user = authenticate_user(db, user.username, user.password)
    if not user:
        raise HTTPException(status_code=401, detail="Incorrect password")

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    refresh_token = create_access_token(data={"sub": user.username}, expires_delta=timedelta(minutes=10080))
    response.set_cookie(key = "refresh_token", path = "/", httponly = True, secure = True, value = refresh_token)

    return {"access_token": access_token, "token_type": "bearer", "refresh_token" : refresh_token}

@app.post("/auth/logout")
def logout():
    refresh_token = create_access_token(data={"sub":""}, expires_delta=timedelta(minutes=0))
    return {"refresh_token" : refresh_token}

def _tried_restaurant_ids(db, user_id):
    """DB ids of restaurants the user has visited or reviewed."""
    visited = db.query(DBUserDinedRestaurants.restaurant_id).filter(DBUserDinedRestaurants.user_id == user_id).all()
    reviewed = db.query(DBReviews.restaurant_id).filter(DBReviews.reviewer_id == user_id).all()
    return {restaurant_id for (restaurant_id,) in visited + reviewed}

@app.post("/recommend")
async def recommend(body: Recommend, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    db_user = _get_db_user(db, current_user)
    tried = _tried_restaurant_ids(db, db_user.id)

    # Only restaurants we've stored can have reviews; skip ones the user already tried.
    candidates = [
        restaurant for restaurant in db.query(DBRestaurant).filter(DBRestaurant.place_id.in_(body.place_ids)).all()
        if restaurant.id not in tried
    ]

    recommendations = RecommendationMap()
    recommendations.recommend(db, db_user.id, [restaurant.id for restaurant in candidates])

    # Optional context from the phone: the search center and its local time (restaurant hours are local too)
    center = (body.lat, body.lng) if body.lat is not None and body.lng is not None else None
    now = (body.day, body.hour, body.minute) if None not in (body.day, body.hour, body.minute) else None

    return [
        {"place_id": restaurant.place_id, "name": restaurant.name, "rating": round(float(rating), 1), "reason": reason, "is_wildcard": is_wildcard}
        for restaurant, rating, reason, is_wildcard in recommendations.top_picks(candidates, center, now)
    ]

@app.get("/tried_restaurants")
async def tried_restaurants(current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    """Place ids the user has visited or reviewed — used by the app's "New" filter."""
    db_user = db.query(DBUser).filter(DBUser.username == current_user.username).first()
    tried = _tried_restaurant_ids(db, db_user.id)
    rows = db.query(DBRestaurant.place_id).filter(DBRestaurant.id.in_(tried)).all()
    return [place_id for (place_id,) in rows]

@app.get("/cuisines")
async def cuisines():
    """Choices for the taste profile screen."""
    return [{"key": key, "label": label} for key, (label, _) in CUISINES.items()]

@app.get("/preferences")
async def get_preferences(current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    db_user = _get_db_user(db, current_user)
    return {"tastes": _taste_list(_user_tastes(db, db_user.id))}

@app.post("/preferences")
async def save_preferences(body: Preferences, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    db_user = _get_db_user(db, current_user)
    # Ignore unknown keys and keep scores in -1..1. Neutral 0s are kept so an all-neutral profile still counts as onboarded.
    tastes = {taste.key: max(-1, min(1, taste.score)) for taste in body.tastes if taste.key in CUISINES}
    prefs = db.query(DBUserPreferences).filter(DBUserPreferences.id == db_user.id).first()
    if prefs is None:
        prefs = DBUserPreferences(id=db_user.id)
        db.add(prefs)
    prefs.food_preferences = json.dumps(tastes)
    db.commit()
    return {"tastes": _taste_list(tastes)}

@app.get("/want_to_go")
async def get_want_to_go(current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    db_user = _get_db_user(db, current_user)
    rows = (
        db.query(DBRestaurant)
        .join(DBWantToGo, DBWantToGo.restaurant_id == DBRestaurant.id)
        .filter(DBWantToGo.user_id == db_user.id)
        .order_by(DBWantToGo.id)
        .all()
    )
    return [{"place_id": r.place_id, "name": r.name} for r in rows]

@app.post("/want_to_go")
async def add_want_to_go(body: WantToGo, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    db_user = _get_db_user(db, current_user)
    db_restaurant = db.query(DBRestaurant).filter(DBRestaurant.place_id == body.place_id).first()
    if db_restaurant is None:
        details = await place_details(body.place_id, 0, 0)
        db_restaurant = DBRestaurant(place_id=body.place_id, name=details["name"], location=json.dumps(details["location"]), primary_type=details["primary_type"])
        db.add(db_restaurant)
        db.commit()
        db.refresh(db_restaurant)
    try:
        db.add(DBWantToGo(user_id=db_user.id, restaurant_id=db_restaurant.id))
        db.commit()
    except IntegrityError:
        db.rollback()  # already saved — that's fine
    return {"place_id": db_restaurant.place_id, "name": db_restaurant.name}

@app.delete("/want_to_go/{place_id}")
async def remove_want_to_go(place_id: str, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    db_user = _get_db_user(db, current_user)
    db_restaurant = db.query(DBRestaurant).filter(DBRestaurant.place_id == place_id).first()
    if db_restaurant is not None:
        db.query(DBWantToGo).filter(
            DBWantToGo.user_id == db_user.id, DBWantToGo.restaurant_id == db_restaurant.id
        ).delete()
        db.commit()
    return {"removed": place_id}

@app.post("/party_recommendation")
async def average_ratings(users, restaurants, db: Session = Depends(get_db)):
    recommendations = PartyRecommendation
    recommendations.find_restaurnats(db, users, restaurants)
    return recommendations


@app.post("/opening_hours")
async def opening_hours(input_hours: Hours, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    breakfast = False
    lunch = False
    dinner = False

    db_place = db.query(DBRestaurant).filter(DBRestaurant.place_id == input_hours.place_id).first()
    # Restaurants saved by /find_restaurants have no hours yet — fetch and cache them.
    if db_place is None or db_place.hours is None:
        details = await place_details(input_hours.place_id, 0, 0)
        if db_place is None:
            db_place = DBRestaurant(place_id=input_hours.place_id, name=details["name"])
            db.add(db_place)
        db_place.hours = json.dumps(details["current_opening_hours"])
        db_place.location = json.dumps(details["location"])
        if not db_place.primary_type:
            db_place.primary_type = details["primary_type"]
        db.commit()

    hours = json.loads(db_place.hours)

    # place_details stores each period as two entries: {"open": ...} then {"close": ...}
    for i in range(0, len(hours) - 1, 2):
        open_hour = hours[i]["open"]["hour"]
        close_hour = hours[i + 1]["close"]["hour"]
        # Closing after midnight (or open 24h, where close comes back as 0) — push it past 24.
        if close_hour <= open_hour:
            close_hour += 24

        if open_hour <= 10:
            breakfast = True
        if open_hour <= 14 and close_hour > 12:
            lunch = True
        if close_hour >= 17:
            dinner = True

    return {"breakfast": breakfast, "lunch": lunch, "dinner": dinner}


#todo:
#send requests through postman
#make auth
#check if it went through by using postgres admin and query through users table


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
    # uvicorn.run("app", host="0.0.0.0", port=8000)






# """ Follow this guide:

# https://betterstack.com/community/guides/scaling-python/authentication-fastapi/
# """