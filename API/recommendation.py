from database import DBUser, get_db, DBUserDinedRestaurants, DBRestaurant, DBReviews, DBUserPreferences, SessionLocal
from models import User, UserCreate, UserForm, UserInformation, VisitedRestaurant, PickLocation, RestaurantRating
from cuisines import CUISINES, cuisine_of, parse_tastes
from geopy.distance import geodesic
import asyncio
import json
import numpy as np
import pandas as pd
from surprise import Dataset, Reader, SVD


ONBOARDING_SCALE = 1.5      # "Love it" counts like a 4.5-star review vs a neutral 3
ONBOARDING_WEIGHT = 2       # onboarding counts like 2 reviews; real reviews take over as they pile up
MIN_SHARED_CUISINES = 3     # fewest shared cuisines needed to compare two taste vectors
MIN_SHARED_RESTAURANTS = 5  # fewest shared restaurants needed to compare two users' ratings
NEUTRAL_RATING = 3
LIKED_RATING = 4            # a rating this high counts as "liked"
STRONG_TASTE = 0.5          # a taste score above this is worth mentioning in the reason
TASTE_NUDGE = 0.5           # how much taste moves a prediction that already has reviews behind it

TOP_PICKS = 5               # how many recommendations to return
MAX_PER_CUISINE = 2         # most picks one cuisine can take, so the list has variety

# Context only changes the order, never the predicted rating the user sees
OPEN_NOW_BONUS = 0.25             # rank boost for places open right now
CLOSING_SOON_MINUTES = 45         # "closes soon" if it closes within this many minutes
CLOSING_SOON_PENALTY = 0.5        # rank drop for places about to close
CLOSED_PENALTY = 1.5              # rank drop for places closed right now
DISTANCE_PENALTY_PER_MILE = 0.1   # rank drop per mile from the search center
MAX_DISTANCE_PENALTY = 1.0        # far places stop losing rank past this

MINUTES_PER_DAY = 24 * 60
MINUTES_PER_WEEK = 7 * MINUTES_PER_DAY


def average(values):
    return sum(values) / len(values)


def weighted_average(pairs):
    """Average of (weight, value) pairs, or None if there are none."""
    total_weight = sum(weight for weight, _ in pairs)
    if total_weight == 0:
        return None
    return sum(weight * value for weight, value in pairs) / total_weight


def people(count):
    return f"{count} {'person' if count == 1 else 'people'}"


def load_ratings(db):
    """Every review, averaged per user and restaurant -> ({user: {restaurant: rating}}, {restaurant: primary_type})."""
    rows = db.query(DBReviews.reviewer_id, DBReviews.restaurant_id, DBReviews.rating, DBRestaurant.primary_type).join(
        DBRestaurant, DBRestaurant.id == DBReviews.restaurant_id
    ).all()

    grouped = {}
    types = {}
    for user, restaurant_id, rating, primary_type in rows:
        grouped.setdefault(user, {}).setdefault(restaurant_id, []).append(rating)  # a user can review a place twice
        types[restaurant_id] = primary_type

    ratings = {
        user: {restaurant_id: average(values) for restaurant_id, values in by_restaurant.items()}
        for user, by_restaurant in grouped.items()
    }
    return ratings, types


def load_onboarding(db):
    """{user: {cuisine_key: score}} for everyone who saved a taste profile."""
    rows = db.query(DBUserPreferences.id, DBUserPreferences.food_preferences).all()
    return {user: parse_tastes(food_preferences) for user, food_preferences in rows}


def load_visited_types(db, user):
    """primary_type of every restaurant this user marked as visited."""
    rows = db.query(DBRestaurant.primary_type).join(
        DBUserDinedRestaurants, DBUserDinedRestaurants.restaurant_id == DBRestaurant.id
    ).filter(DBUserDinedRestaurants.user_id == user).all()
    return [primary_type for (primary_type,) in rows]


def taste_vector(onboarding, reviews):
    """How much a user likes each cuisine (0 = neutral, + likes, - dislikes). Cuisines with no signal are left out.

    onboarding: {cuisine_key: -1|0|1}, reviews: [(rating, primary_type), ...] with one entry per restaurant.
    """
    totals = {}
    counts = {}
    for key, score in onboarding.items():
        totals[key] = ONBOARDING_WEIGHT * score * ONBOARDING_SCALE
        counts[key] = ONBOARDING_WEIGHT
    for rating, primary_type in reviews:
        key = cuisine_of(primary_type)
        if key is None:
            continue
        totals[key] = totals.get(key, 0) + rating - NEUTRAL_RATING
        counts[key] = counts.get(key, 0) + 1
    return {key: totals[key] / counts[key] for key in totals}


def pearson(a, b):
    """Correlation of two equal-length lists (-1..1), or None if either has no spread."""
    if np.std(a) == 0 or np.std(b) == 0:
        return None
    return float(np.corrcoef(a, b)[0][1])


def taste_similarity(a, b):
    """Correlation of two taste vectors over the cuisines both have; 0 if there are too few or no spread."""
    shared = [key for key in a if key in b]
    if len(shared) < MIN_SHARED_CUISINES:
        return 0
    return pearson([a[key] for key in shared], [b[key] for key in shared]) or 0


def restaurant_similarity(mine, theirs):
    """Correlation of ratings on restaurants both users rated; None if there are too few or no spread."""
    shared = [restaurant_id for restaurant_id in theirs if restaurant_id in mine]
    if len(shared) < MIN_SHARED_RESTAURANTS:
        return None
    return pearson([mine[restaurant_id] for restaurant_id in shared], [theirs[restaurant_id] for restaurant_id in shared])


def similarity(my_vector, their_vector, my_ratings, their_ratings):
    """How alike two users are (-1..1): taste vectors, averaged with shared-restaurant ratings when there are enough."""
    taste = taste_similarity(my_vector, their_vector)
    restaurants = restaurant_similarity(my_ratings, their_ratings)
    if restaurants is None:
        return taste
    return (taste + restaurants) / 2


def minute_of_week(time):
    """{"day", "hour", "minute"} -> minutes since Sunday 00:00."""
    return time["day"] * MINUTES_PER_DAY + time["hour"] * 60 + time["minute"]


def open_status(periods, day, hour, minute):
    """"open", "closing_soon" or "closed" at this time (day 0 = Sunday, like Google), or None if hours are unknown.

    periods: [{"open": {day, hour, minute}, "close": {...}}]. Same week math as the app's isOpen.
    """
    periods = [period for period in periods if period.get("open")]
    if not periods:
        return None
    now = day * MINUTES_PER_DAY + hour * 60 + minute
    opening_times = {minute_of_week(period["open"]) for period in periods}

    for period in periods:
        if not period.get("close"):
            return "open"  # no close time = open 24 hours
        start = minute_of_week(period["open"])
        end = minute_of_week(period["close"])
        if end <= start:
            end += MINUTES_PER_WEEK  # e.g. opens Saturday night, closes Sunday (a 24h place has open == close)
        # Check `now` and `now + 1 week` so periods that wrap past Saturday still match
        for time in (now, now + MINUTES_PER_WEEK):
            if start <= time < end:
                reopens = end % MINUTES_PER_WEEK in opening_times  # 24h places and back-to-back periods never really close
                if end - time <= CLOSING_SOON_MINUTES and not reopens:
                    return "closing_soon"
                return "open"
    return "closed"


def context_adjustment(hours, location, center=None, now=None):
    """(rank change, note for the reason) from whether a place is open and how far away it is.

    hours: its opening periods, location: [lat, lng] or None,
    center: (lat, lng) of the search or None, now: (day, hour, minute) on the phone or None.
    """
    change = 0
    note = ""
    if now is not None:
        status = open_status(hours, *now)
        if status == "open":
            change += OPEN_NOW_BONUS
        elif status == "closing_soon":
            change -= CLOSING_SOON_PENALTY
            note = " · Closes soon"
        elif status == "closed":
            change -= CLOSED_PENALTY
            note = " · Closed now"
    if center is not None and location:
        miles = geodesic(center, location).miles
        change -= min(MAX_DISTANCE_PENALTY, DISTANCE_PENALTY_PER_MILE * miles)
    return change, note


def pick_top(scores, cuisines, is_wildcard_cuisine):
    """Choose what to show -> (picks best first, wildcard restaurant or None).

    scores: {restaurant: rank score}, cuisines: {restaurant: cuisine key or None}.
    At most MAX_PER_CUISINE picks per cuisine (unknown cuisines share one bucket), and one wildcard slot
    for the best place whose cuisine passes is_wildcard_cuisine.
    """
    ranked = sorted(scores, key=lambda restaurant_id: -scores[restaurant_id])
    wildcard = next((rid for rid in ranked if is_wildcard_cuisine(cuisines[rid])), None)

    counts = {}  # {cuisine: picks so far}
    if wildcard is not None:
        counts[cuisines[wildcard]] = 1  # the wildcard uses up one of its cuisine's spots
    slots = TOP_PICKS - (1 if wildcard is not None else 0)

    picks = []
    for restaurant_id in ranked:
        if len(picks) == slots:
            break
        cuisine = cuisines[restaurant_id]
        if restaurant_id == wildcard or counts.get(cuisine, 0) >= MAX_PER_CUISINE:
            continue
        picks.append(restaurant_id)
        counts[cuisine] = counts.get(cuisine, 0) + 1

    # Not enough variety to fill every slot: top up with the best leftovers
    leftovers = [rid for rid in ranked if rid != wildcard and rid not in picks]
    picks += leftovers[:slots - len(picks)]
    picks.sort(key=lambda restaurant_id: -scores[restaurant_id])
    return picks, wildcard


class RecommendationMap:
    def __init__(self):
        self.user_similarity = {}     # {user: similarity to me, -1..1}
        self.overlap_counts = {}      # {user: number of restaurants we both rated}
        self.restaurant_ratings = {}  # {restaurant: predicted rating, 1-5}
        self.reasons = {}             # {restaurant: why it's recommended}
        self.my_vector = {}           # {cuisine_key: my taste score}
        self.vectors = {}             # {user: their taste vector}
        self.twins = {}               # {user: similarity} for users with similarity > 0
        self.cuisines = {}            # {restaurant: cuisine key or None}
        self.my_onboarding = {}       # {cuisine_key: -1|0|1} from my taste profile
        self.tried_cuisines = set()   # cuisines I've reviewed or visited

    def recommend(self, db, user, restaurant_ids):
        """Predict this user's rating (and a reason) for each restaurant id."""
        ratings, types = load_ratings(db)
        candidate_types = db.query(DBRestaurant.id, DBRestaurant.primary_type).filter(DBRestaurant.id.in_(restaurant_ids)).all()
        types.update({restaurant_id: primary_type for restaurant_id, primary_type in candidate_types})
        self.predict(user, restaurant_ids, ratings, types, load_onboarding(db), load_visited_types(db, user))

    def predict(self, user, restaurant_ids, ratings, types, onboarding, visited_types=()):
        """The scoring step, kept apart from the DB loading so it can be tried with made-up users."""
        # Step 1: a taste vector for everyone who has reviews or a taste profile
        for uid in set(ratings) | set(onboarding) | {user}:
            reviews = [(rating, types[restaurant_id]) for restaurant_id, rating in ratings.get(uid, {}).items()]
            self.vectors[uid] = taste_vector(onboarding.get(uid, {}), reviews)
        self.my_vector = self.vectors[user]
        self.my_onboarding = onboarding.get(user, {})
        tried_types = [types[restaurant_id] for restaurant_id in ratings.get(user, {})] + list(visited_types)
        self.tried_cuisines = {cuisine_of(primary_type) for primary_type in tried_types} - {None}

        # Step 2: how similar each other user is to me; "twins" are the positive ones
        my_ratings = ratings.get(user, {})
        for uid, vector in self.vectors.items():
            if uid == user:
                continue
            their_ratings = ratings.get(uid, {})
            self.overlap_counts[uid] = len(my_ratings.keys() & their_ratings.keys())
            self.user_similarity[uid] = similarity(self.my_vector, vector, my_ratings, their_ratings)
        self.twins = {uid: sim for uid, sim in self.user_similarity.items() if sim > 0}

        # Step 3: predict each restaurant from who rated it and how much we like its cuisine
        reviewers = {}  # {restaurant: {user: rating}}
        for uid, by_restaurant in ratings.items():
            for restaurant_id, rating in by_restaurant.items():
                reviewers.setdefault(restaurant_id, {})[uid] = rating

        for restaurant_id in restaurant_ids:
            cuisine = cuisine_of(types.get(restaurant_id))
            rating, reason = self._predict_one(cuisine, reviewers.get(restaurant_id, {}))
            self.cuisines[restaurant_id] = cuisine
            self.restaurant_ratings[restaurant_id] = rating
            self.reasons[restaurant_id] = reason

    def twin_taste(self, cuisine):
        """How much my twins like this cuisine, weighted by how similar they are; None if none of them have a say."""
        return weighted_average([
            (sim, self.vectors[uid][cuisine]) for uid, sim in self.twins.items() if cuisine in self.vectors[uid]
        ])

    def is_wildcard_cuisine(self, cuisine):
        """A cuisine worth a discovery slot: I've never tried it, didn't say love it or "not for me", and my twins love it."""
        if cuisine is None or cuisine in self.tried_cuisines:
            return False
        if self.my_onboarding.get(cuisine) in (1, -1):
            return False
        twin_taste = self.twin_taste(cuisine)
        return twin_taste is not None and twin_taste > STRONG_TASTE

    def top_picks(self, restaurants, center=None, now=None):
        """The restaurants to show -> [(restaurant, rating, reason, is_wildcard)], wildcard last.

        restaurants: the DB rows passed to recommend(). Being open and close by (center = (lat, lng),
        now = (day, hour, minute)) only changes the order; the rating stays the pure prediction.
        """
        by_id = {restaurant.id: restaurant for restaurant in restaurants}
        scores = {}
        notes = {}
        for restaurant in restaurants:
            hours = json.loads(restaurant.hours) if restaurant.hours else []
            location = json.loads(restaurant.location) if restaurant.location else None
            change, notes[restaurant.id] = context_adjustment(hours, location, center, now)
            scores[restaurant.id] = self.restaurant_ratings[restaurant.id] + change

        picks, wildcard = pick_top(scores, self.cuisines, self.is_wildcard_cuisine)
        results = [(by_id[rid], self.restaurant_ratings[rid], self.reasons[rid] + notes[rid], False) for rid in picks]
        if wildcard is not None:
            label = CUISINES[self.cuisines[wildcard]][0]
            reason = f"People with your taste love {label} — you haven't tried it" + notes[wildcard]
            results.append((by_id[wildcard], self.restaurant_ratings[wildcard], reason, True))
        return results

    def _predict_one(self, cuisine, reviewers):
        """(predicted rating, reason) for one restaurant. reviewers: {user: rating}; cuisine may be None."""
        # Base: what my twins rated it, else what everyone rated it, else neutral
        twin_ratings = [(self.twins[uid], rating) for uid, rating in reviewers.items() if uid in self.twins]
        if twin_ratings:
            base = weighted_average(twin_ratings)
        elif reviewers:
            base = average(list(reviewers.values()))
        else:
            base = NEUTRAL_RATING

        # Taste: how much I (and my twins) like this cuisine
        own = self.my_vector.get(cuisine)
        twin_taste = self.twin_taste(cuisine)
        tastes = [value for value in (own, twin_taste) if value is not None]
        taste = average(tastes) if tastes else 0

        # With no reviews, taste is the only signal; otherwise it just nudges the reviews
        prediction = base + taste if not reviewers else base + TASTE_NUDGE * taste
        prediction = min(max(prediction, 1), 5)

        likers = sum(1 for uid, rating in reviewers.items() if uid in self.twins and rating >= LIKED_RATING)
        if likers and prediction > NEUTRAL_RATING:  # don't say "liked by" about a place we expect you to dislike
            reason = f"Liked by {people(likers)} with your taste"
        elif own is not None and own > STRONG_TASTE:
            reason = f"Matches your taste: {CUISINES[cuisine][0]}"
        elif twin_taste is not None and twin_taste > STRONG_TASTE:
            reason = f"People with your taste love {CUISINES[cuisine][0]}"
        elif reviewers:
            reason = f"Rated {average(list(reviewers.values())):.1f} by {people(len(reviewers))}"
        else:
            reason = "No ratings yet"
        return prediction, reason


async def test_map():
    db = SessionLocal()
    user = db.query(DBUser).filter(DBUser.username == "seed_asian_1").first().id

    # restaurants I haven't rated yet, to get a predicted rating for
    rated_ids = {rid for (rid,) in db.query(DBReviews.restaurant_id).filter(DBReviews.reviewer_id == user).all()}
    all_restaurants = db.query(DBRestaurant.id, DBRestaurant.name).all()
    candidates = [(rid, name) for rid, name in all_restaurants if rid not in rated_ids]

    recommendations = RecommendationMap()
    recommendations.recommend(db, user, [rid for rid, _ in candidates])

    names = {u.id: u.username for u in db.query(DBUser).all()}
    print("--- my taste ---")
    for key, score in sorted(recommendations.my_vector.items(), key=lambda x: -x[1]):
        print(f"{key:16} {score:+.2f}")

    print("--- similarity ---")
    for uid, sim in sorted(recommendations.user_similarity.items(), key=lambda x: -x[1]):
        print(f"{names[uid]:16} {sim:+.2f}  shared restaurants: {recommendations.overlap_counts[uid]}")

    restaurant_names = dict(candidates)
    print("--- predicted ratings ---")
    for rid, rating in sorted(recommendations.restaurant_ratings.items(), key=lambda x: -x[1])[:10]:
        print(f"{restaurant_names[rid]:30} {rating:.2f}  {recommendations.reasons[rid]}")

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
