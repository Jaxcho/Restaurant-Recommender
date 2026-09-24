from database import DBUser, get_db, DBUserDinedRestaurants, DBRestaurant, DBReviews, SessionLocal
from models import User, UserCreate, UserForm, UserInformation, VisitedRestaurant, PickLocation, RestaurantRating
import asyncio
import numpy as np
import pandas as pd
from surprise import Dataset, Reader, SVD


class RecommendationMap:
    def __init__(self):
        self.similar_restaurants = {} # user restaurants, {restaurant: rating, ...}
        self.similar_users = {} # {UUID:{rating:resturant, ...} ...} for all similar restaurants
        self.final_users = {}
        self.user_similarity = {} # {user: similarity, ...}
        self.user_restuarants = {}  # rating, restaurant ID 
        self.restaurant_ratings = {} # {restaurant: Expected rating}

    def users(self, db, user):
        #DBs
        
        self.user_restaurants = db.query( DBReviews.rating, DBRestaurant.id).filter(DBReviews.reviewer_id == user, DBRestaurant.id==DBReviews.restaurant_id).all() # rating, restaurant ID 
        restaurant_ids = [restaurant for _, restaurant in self.user_restaurants]

        all_reviews = db.query(DBReviews.reviewer_id, DBReviews.rating, DBReviews.restaurant_id).filter(DBReviews.restaurant_id.in_(restaurant_ids), DBReviews.reviewer_id!=user).all() #Reviewer ID, rating, restaurant ID


        #Averaging out multiple ratings and returns data

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

        # Loops through each user and compares with main user
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

            # Finding matching rated restaurants
            
            for restaurant in user_restaurants:
                users.append(user_restaurants[restaurant])
            for restaurant in restaurants:
                other_restaurants.append(restaurants[restaurant])

            # Similarity function
            similarity = np.corrcoef(users, other_restaurants)
            print(similarity)
            self.user_similarity[user] = similarity[0][1]


        
    def order_restaurants(self, restaurants):
        pass

async def test_map():
    db = SessionLocal()
    map = RecommendationMap
    print(vars(map))
    db.close()

if __name__ == "__main__":
    asyncio.run(test_map())




# def train_model(db):
#     reviews = db.query(DBReviews.reviewer_id, DBReviews.restaurant_id, DBReviews.rating).all()
#     df = pd.DataFrame(reviews, columns=["user", "restaurant", "rating"])
#     df["user"] = df["user"].astype(str)
#     df["restaurant"] = df["restaurant"].astype(str)

#     reader = Reader(rating_scale=(1, 5))
#     data = Dataset.load_from_df(df[["user", "restaurant", "rating"]], reader)

#     trainset = data.build_full_trainset()
#     model = SVD()
#     model.fit(trainset)
#     return model


# def predict_rating(model, user_id, restaurant_id):
#     prediction = model.predict(str(user_id), str(restaurant_id))
#     return prediction.est