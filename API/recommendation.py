from database import DBUser, get_db, DBUserDinedRestaurants, DBRestaurant, DBReviews, SessionLocal
from models import User, UserCreate, UserForm, UserInformation, VisitedRestaurant, PickLocation, RestaurantRating
import asyncio

class RecommendationMap:
    def __init__(self):
        self.map = {}

    def fill_map(self, db, user):
        #restaurants user has rated
        #go through each and find the other reviewers
        #
        user_restaurants = db.query( DBReviews.rating, DBRestaurant.id).filter(DBReviews.reviewer_id == user, DBRestaurant.id==DBReviews.restaurant_id).all()

        restaurant_ids = [restaurant for rating, restaurant in user_restaurants]

        similar_ratings = {}

        all_reviews = db.query(DBReviews.reviewer_id, DBReviews.rating, DBReviews.restaurant_id).filter(DBReviews.restaurant_id.in_(restaurant_ids), DBReviews.reviewer_id!=user).all()
        for uid, rating, restaurant in all_reviews:
            if uid not in similar_ratings:
                similar_ratings[uid] = {}
            similar_ratings[uid][rating] = restaurant



        self.map = similar_ratings
        return self.map


async def test_map():
    user = "57c7e005-8270-47b2-acc1-22f6fa3d55cf"
    db = SessionLocal()
    # user_restaurants = db.query(DBReviews).filter(DBReviews.reviewer_name == user)
    user_map = RecommendationMap()
    print(user_map.fill_map(db, user))
    db.close()

if __name__ == "__main__":
    asyncio.run(test_map())