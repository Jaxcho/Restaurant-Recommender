"""Seed fake users + reviews on existing SF restaurants to test the recommender.

    python3 seed_reviews.py          # wipe old seed data, then seed
    python3 seed_reviews.py --reset  # only wipe seed data

All seed users are named seed_* with password "password123".
"""
import random
import sys

from auth import get_password_hash
from database import SessionLocal, DBUser, DBRestaurant, DBReviews

SEED_PREFIX = "seed_"
PASSWORD = "password123"

CATEGORIES = {
    "chinese": ["Yank Sing", "Good Luck Dim Sum", "Hong Kong Lounge", "Dragon Beaux", "R & G Lounge", "San Tung", "Dumpling Home"],
    "japanese": ["Marufuku Ramen", "IPPUDO San Francisco", "HINODEYA Ramen Union Square", "Mensho Tokyo SF", "Chotto Matte San Francisco"],
    "korean_burmese": ["Han Il Kwan", "Daeho Kalbijim & Beef Soup", "Burma Superstar", "Burma Love", "Mandalay Restaurant"],
    "mexican_latin": ["La Taqueria", "Tropisueno", "Chipotle Mexican Grill", "Copra", "La Mar Cocina Peruana San Francisco"],
    "italian": ["Tony's Pizza Napoletana", "Che Fico", "Little Original Joe's", "Pasta Supply Co", "Bella Trattoria", "Sotto Mare"],
    "mediterranean": ["Kokkari Estiatorio", "Souvla", "Dalida Restaurant", "Lokma"],
    "bakery_brunch": ["Tartine Bakery", "Tartine Manufactory", "Breadbelly", "Sweet Maple", "Zazie", "Jane on Fillmore", "Brenda's French Soul Food"],
    "fast_food": ["McDonald's", "In-N-Out Burger", "Super Duper Burgers", "Jack in the Box", "Mel's Drive-In", "The Melt"],
    "upscale": ["Gary Danko", "State Bird Provisions", "Nopa", "Zuni Café", "Spruce", "House of Prime Rib", "Wayfare Tavern"],
}

# How much each taste group likes each category (1-5). Unlisted categories = 3.
PERSONAS = {
    "asian":  {"chinese": 5, "japanese": 5, "korean_burmese": 4.5, "fast_food": 1.5},
    "fine":   {"upscale": 5, "italian": 4.5, "mediterranean": 4.5, "fast_food": 1},
    "budget": {"fast_food": 5, "mexican_latin": 4.5, "upscale": 1.5},
    "brunch": {"bakery_brunch": 5, "mediterranean": 4.5, "japanese": 2},
    "latin":  {"mexican_latin": 5, "korean_burmese": 4.5, "bakery_brunch": 1.5},
}
USERS_PER_PERSONA = 4

# Some places are just better/worse than their category average.
QUALITY_BUMP = {
    "Gary Danko": 0.5, "State Bird Provisions": 0.5, "Tartine Bakery": 0.5,
    "La Taqueria": 0.5, "Marufuku Ramen": 0.5, "Yank Sing": 0.5,
    "Chipotle Mexican Grill": -0.5, "McDonald's": -0.5, "Jack in the Box": -0.5,
}


def reset(db):
    seed_users = db.query(DBUser).filter(DBUser.username.startswith(SEED_PREFIX)).all()
    seed_ids = [user.id for user in seed_users]
    deleted = db.query(DBReviews).filter(DBReviews.reviewer_id.in_(seed_ids)).delete(synchronize_session=False)
    for user in seed_users:
        db.delete(user)
    db.commit()
    print(f"Removed {len(seed_users)} seed users and {deleted} reviews")


def load_restaurants(db):
    """Returns [(restaurant_id, name, category), ...] using the lowest id per name."""
    restaurants = []
    for category, names in CATEGORIES.items():
        for name in names:
            restaurant = db.query(DBRestaurant).filter(DBRestaurant.name == name).order_by(DBRestaurant.id).first()
            if restaurant is None:
                print(f"  skipping {name!r}: not in restaurants table")
                continue
            restaurants.append((restaurant.id, name, category))
    return restaurants


def make_rating(persona, name, category):
    score = PERSONAS[persona].get(category, 3) + QUALITY_BUMP.get(name, 0) + random.gauss(0, 0.6)
    return float(min(5, max(1, round(score))))


def seed(db):
    random.seed(42)  # same data every run
    restaurants = load_restaurants(db)
    hashed_password = get_password_hash(PASSWORD)

    review_count = 0
    for persona in PERSONAS:
        for i in range(1, USERS_PER_PERSONA + 1):
            username = f"{SEED_PREFIX}{persona}_{i}"
            user = DBUser(username=username, email=f"{username}@test.com",
                          full_name=username, hashed_password=hashed_password)
            db.add(user)
            db.flush()  # gives user.id

            coverage = random.uniform(0.5, 0.7)
            for restaurant_id, name, category in random.sample(restaurants, round(len(restaurants) * coverage)):
                db.add(DBReviews(restaurant_id=restaurant_id, reviewer_id=user.id, reviewer_name=username,
                                 content="", rating=make_rating(persona, name, category)))
                review_count += 1

    db.commit()
    print(f"Seeded {len(PERSONAS) * USERS_PER_PERSONA} users, {len(restaurants)} restaurants, {review_count} reviews")


if __name__ == "__main__":
    db = SessionLocal()
    try:
        reset(db)
        if "--reset" not in sys.argv:
            seed(db)
    finally:
        db.close()
