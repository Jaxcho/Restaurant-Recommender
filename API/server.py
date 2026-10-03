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
from auth import (authenticate_user, create_access_token, get_current_active_user, fake_users_db, ACCESS_TOKEN_EXPIRE_MINUTES, get_password_hash, decode_token, token_validation)
from database import DBUser, get_db, DBUserDinedRestaurants, DBRestaurant, DBReviews, DBQueries, DBQueriedRestaurants
from recommendation import RecommendationMap
from models import User, UserCreate, UserForm, UserInformation, VisitedRestaurant, PickLocation, RestaurantRating, Autocomplete, Hours
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from pick_location import geocode

app = FastAPI(title="Authentication Demo", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])


def _restaurant_with_flags(place_id, name, hours_json):
    """Rebuild a restaurant's meal flags from its stored opening-hours JSON."""
    periods = json.loads(hours_json) if hours_json else []
    return {"id": place_id, "name": name, **meal_availability(periods)}

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
async def pick_location(body:PickLocation, user = Depends(get_current_active_user) ):
    response = geocode(body.address)
    if response is None:
        raise HTTPException(status_code=404, detail="Address not found")
    # Nominatim returns coordinates as strings
    lat = float(response["lat"])
    lng = float(response["lon"])
    data = await nearby_search(lat, lng, body.radius*1609.344)
    return {"lat": lat, "lng": lng, "restaurants": data}

@app.post("/post_review")
async def rate_restaurant( restaurant_rating: RestaurantRating, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    
    place_id = restaurant_rating.place_id
    db_restaurant = db.query(DBRestaurant).filter(DBRestaurant.place_id == place_id).first()
    if db_restaurant is None:
        details = await place_details(place_id, 0, 0)
        db_restaurant = DBRestaurant(place_id=place_id, name=details["name"])
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
            return [_restaurant_with_flags(r.place_id, r.name, r.hours) for r in saved]



    data = await nearby_search(lat, lng, radius)

    db_query = DBQueries(lat=lat, lng=lng, radius=radius)
    db.add(db_query)
    db.flush()

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

        db.add(DBQueriedRestaurants(queried_id=db_query.id, restaurant_id=db_restaurant.id))

    db.commit()
    # Drop the raw `hours` from the response — the app only needs the meal flags.
    return [
        {"id": r["id"], "name": r["name"], "breakfast": r["breakfast"], "lunch": r["lunch"], "dinner": r["dinner"]}
        for r in data
    ]
     
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
    existing_user = db.query(DBUser).filter(DBUser.username == user.username).first()
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
    existing_user = db.query(DBUser).filter(DBUser.username == user.username).first()
    if not existing_user:
        raise HTTPException(status_code=404, detail="User not found")
    user = authenticate_user(db, user.username, user.password)
    if not user:
        raise HTTPException(status_code=401, detail="Unauthorized")

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

@app.post("/recommend")
async def recommend(restaurants, current_user: User = Depends(get_current_active_user), db: Session = Depends(get_db)):
    restaurants = RecommendationMap.recommend( db, current_user,  restaurants)
    


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