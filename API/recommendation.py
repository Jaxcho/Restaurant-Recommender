from database import DBUser, get_db, DBUserDinedRestaurants, DBRestaurant, DBReviews, SessionLocal
from models import User, UserCreate, UserForm, UserInformation, VisitedRestaurant, PickLocation, RestaurantRating
import asyncio
import numpy as np




class RecommendationMap:
    def __init__(self):
        self.similar_restaurants = {} # user restaurants, {restaurant: rating, ...}
        self.similar_users = {} # {UUID:{rating:resturant, ...} ...} for all similar restaurants
        self.final_users = {}
        self.user_similarity = {} # {user: similarity, ...}
        self.user_restuarants = {}  # rating, restaurant ID 
        self.restaurant_ratings = {} # {restaurant: Expected rating}

    def users(self, db, user):
        #restaurants user has rated
        #go through each and find the other reviewers
        
        self.user_restaurants = db.query( DBReviews.rating, DBRestaurant.id).filter(DBReviews.reviewer_id == user, DBRestaurant.id==DBReviews.restaurant_id).all() # rating, restaurant ID 
        restaurant_ids = [restaurant for _, restaurant in self.user_restaurants]

        # all_reviews = db.query(DBReviews.reviewer_id, DBReviews.rating, DBReviews.restaurant_id).filter(DBReviews.reviewer_id!=user).all() #Reviewer ID, rating, restaurant ID
        all_reviews = db.query(DBReviews.reviewer_id, DBReviews.rating, DBReviews.restaurant_id).filter(DBReviews.restaurant_id.in_(restaurant_ids), DBReviews.reviewer_id!=user).all() #Reviewer ID, rating, restaurant ID

        # self.user_restuarants = db.query( DBReviews.rating, DBRestaurant.id).filter(DBReviews.reviewer_id == user, DBRestaurant.id==DBReviews.restaurant_id).all() # rating, restaurant ID 



        for uuid, rating, restaurant in all_reviews:
            if uuid not in self.similar_users:
                self.similar_users[uuid] = {}
            self.similar_users[uuid].setdefault(restaurant, []).append(rating)

        for uuid in self.similar_users:
            self.final_users[uuid] = {}
            for rest, ratings in self.similar_users[uuid].items():
                self.final_users[uuid][rest] = sum(ratings) / len(ratings)
        return self.final_users

        
    def find_similarity(self):
        for user in self.final_users:
            user_restaurants = {}
            users = []
            restaurants = self.final_users[user]
            other_restaurants = []
            for restaurant in restaurants:
                for val in self.user_restaurants:
                    if restaurant == val[1]:
                        user_restaurants[restaurant] = val[0]
                        break     
                    
            for restaurant in user_restaurants:
                users.append(user_restaurants[restaurant])
            for restaurant in restaurants:
                other_restaurants.append(restaurants[restaurant])
            similarity = np.corrcoef(users, other_restaurants)
            print(similarity)
            self.user_similarity[user] = similarity[0][1]


        
    def order_restaurants(self, restaurants):
        pass


async def test_map():
    user = "6e892122-802c-4468-b0d2-b72c3cda1396"
    db = SessionLocal()
    # user_restaurants = db.query(DBReviews).filter(DBReviews.reviewer_name == user)
    user_map = RecommendationMap()
    user_map.users(db, user)
    user_map.find_similarity()
    print(vars(user_map), "USERMAP")
    # print(user_map.find_similarity())
    db.close()

if __name__ == "__main__":
    asyncio.run(test_map())


"""
 (6e892122-802c-4468-b0d2-b72c3cda1396,1)
 (c81606d8-6ef3-4980-922f-47a69acfedf8,2) -> 1
 (394052a8-a47c-434c-b8be-dd6facef28de,3) -> 3
 (f0bcbcd6-825a-4966-b609-e4a3d09df652,4) -> 4
"""