from database import DBUser, get_db, DBUserDinedRestaurants, DBRestaurant, DBReviews, SessionLocal
from models import User, UserCreate, UserForm, UserInformation, VisitedRestaurant, PickLocation, RestaurantRating
import asyncio
import numpy as np
import pandas as pd
from surprise import Dataset, Reader, SVD


class RecommendationMap:
    def __init__(self):
        self.user_similarity = {}     # {user: similarity}
        self.overlap_counts = {}      # {user: number of shared restaurants}
        self.restaurant_ratings = {}  # {restaurant: predicted rating}

    def recommend(self, db, user, restaurants):
        # --- Step 1: load my ratings and everyone else's ratings on those same restaurants ---
        my_reviews = db.query(DBReviews.rating, DBRestaurant.id).filter(
            DBReviews.reviewer_id == user, DBRestaurant.id == DBReviews.restaurant_id
        ).all()
        restaurant_ids = [restaurant_id for _, restaurant_id in my_reviews]

        other_reviews = db.query(DBReviews.reviewer_id, DBReviews.rating, DBReviews.restaurant_id).filter(
            DBReviews.restaurant_id.in_(restaurant_ids), DBReviews.reviewer_id != user
        ).all()  # Reviewer ID, rating, restaurant ID

        # average out my own ratings in case I reviewed a place more than once
        my_ratings_raw = {}
        for rating, restaurant_id in my_reviews:
            my_ratings_raw.setdefault(restaurant_id, []).append(rating)
        my_ratings = {
            restaurant_id: sum(ratings) / len(ratings)
            for restaurant_id, ratings in my_ratings_raw.items()
        }

        # group each other user's ratings by restaurant, then average duplicates
        other_users = {}
        for uuid, rating, restaurant_id in other_reviews:
            other_users.setdefault(uuid, {}).setdefault(restaurant_id, []).append(rating)
        other_user_ratings = {
            uuid: {
                restaurant_id: sum(ratings) / len(ratings)
                for restaurant_id, ratings in restaurant_map.items()
            }
            for uuid, restaurant_map in other_users.items()
        }

        # --- Step 2: similarity between me and each other user ---
        for uuid, their_ratings_by_restaurant in other_user_ratings.items():
            my_shared = []
            their_shared = []
            for restaurant_id, their_rating in their_ratings_by_restaurant.items():
                if restaurant_id in my_ratings:
                    my_shared.append(my_ratings[restaurant_id])
                    their_shared.append(their_rating)

            self.overlap_counts[uuid] = len(my_shared)

            # Not enough overlap (or no spread) for a meaningful correlation
            if len(my_shared) < 5 or np.std(my_shared) == 0 or np.std(their_shared) == 0:
                self.user_similarity[uuid] = 0
                continue

            similarity = np.corrcoef(my_shared, their_shared)
            self.user_similarity[uuid] = similarity[0][1]

        # --- Step 3: predict my rating for each candidate restaurant ---
        # weighted average of similar users' ratings, weighted by their similarity to me
        for restaurant_id in restaurants:
            reviewers = db.query(DBReviews.reviewer_id, DBReviews.rating).filter(
                DBReviews.restaurant_id == restaurant_id
            ).all()

            weighted_sum = 0
            weight_total = 0
            for reviewer_id, rating in reviewers:
                similarity = self.user_similarity.get(reviewer_id, 0)
                if similarity <= 0:
                    continue  # only "similar" users should steer the prediction
                weighted_sum += similarity * rating
                weight_total += similarity

            self.restaurant_ratings[restaurant_id] = weighted_sum / weight_total if weight_total != 0 else 3


async def test_map():
    db = SessionLocal()
    user = db.query(DBUser).filter(DBUser.username == "seed_asian_1").first().id

    # restaurants I haven't rated yet, to get a predicted rating for
    rated_ids = {rid for _, rid in db.query(DBReviews.restaurant_id, DBRestaurant.id).filter(
        DBReviews.reviewer_id == user, DBRestaurant.id == DBReviews.restaurant_id).all()}
    all_restaurants = db.query(DBRestaurant.id, DBRestaurant.name).all()
    candidates = [(rid, name) for rid, name in all_restaurants if rid not in rated_ids]

    recommendations = RecommendationMap()
    recommendations.recommend(db, user, [rid for rid, _ in candidates])

    names = {u.id: u.username for u in db.query(DBUser).all()}
    print("--- similarity ---")
    for uid, sim in sorted(recommendations.user_similarity.items(), key=lambda x: -x[1]):
        print(f"{names[uid]:16} {sim:.2f}  shared: {recommendations.overlap_counts[uid]}")

    restaurant_names = dict(candidates)
    print("--- predicted ratings ---")
    for rid, rating in sorted(recommendations.restaurant_ratings.items(), key=lambda x: -x[1])[:10]:
        print(f"{restaurant_names[rid]:30} {rating:.2f}")

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
