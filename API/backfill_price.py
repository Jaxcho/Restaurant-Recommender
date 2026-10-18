"""Fill in price_per_person for restaurants saved before we asked Google for prices.

    python3 backfill_price.py --dry-run  # only print what would change
    python3 backfill_price.py            # update the database

Cached searches never call Google again, so their restaurants only get a price from this.
"""
import asyncio
import sys

from google.api_core.exceptions import ResourceExhausted
from google.maps import places_v1

from database import SessionLocal, DBRestaurant
from location import _client, price_per_person

FIELD_MASK = "priceRange"


async def backfill(db, dry_run):
    client = _client()
    restaurants = db.query(DBRestaurant).filter(DBRestaurant.price_per_person.is_(None)).order_by(DBRestaurant.id).all()
    print(f"Checking {len(restaurants)} restaurants with no price...")

    updated, no_price, failed = 0, 0, []
    for restaurant in restaurants:
        try:
            request = places_v1.GetPlaceRequest(name=f"places/{restaurant.place_id}")
            place = await client.get_place(request=request, metadata=[("x-goog-fieldmask", FIELD_MASK)])
        except ResourceExhausted:  # daily quota used up, so every remaining request would fail too
            print("Google quota used up for today - stopping early. Run again later to finish.")
            break
        except Exception as error:  # one bad place shouldn't stop the whole run
            failed.append((restaurant.name, str(error).splitlines()[0]))
            continue

        price = price_per_person(place)
        if price is None:
            no_price += 1
            continue
        print(f"  {restaurant.name}: ${price}")
        updated += 1
        if not dry_run:
            restaurant.price_per_person = price

    print(f"\n{'Would update' if dry_run else 'Updated'}: {updated}")
    print(f"Google has no price: {no_price}")
    print(f"Failed: {len(failed)}")
    for name, error in failed:
        print(f"  {name}: {error}")

    if not dry_run:
        db.commit()


if __name__ == "__main__":
    db = SessionLocal()
    try:
        asyncio.run(backfill(db, dry_run="--dry-run" in sys.argv))
    finally:
        db.close()
