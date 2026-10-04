"""Fill in missing or non-cuisine primary_type values from Google, so more restaurants get a cuisine.

    python3 backfill_primary_type.py --dry-run  # only print what would change
    python3 backfill_primary_type.py            # update the database

Checks every restaurant whose primary_type is empty or isn't a cuisine (e.g. "restaurant", "hotel").
"""
import asyncio
import sys

from google.api_core.exceptions import ResourceExhausted
from google.maps import places_v1

from cuisines import cuisine_of, resolve_type
from database import SessionLocal, DBRestaurant
from location import _client

FIELD_MASK = "primaryType,types"


async def fetch_type(client, place_id):
    """(best type for this place, Google's full types list)."""
    request = places_v1.GetPlaceRequest(name=f"places/{place_id}")
    place = await client.get_place(request=request, metadata=[("x-goog-fieldmask", FIELD_MASK)])
    types = list(place.types)
    return resolve_type(place.primary_type, types), types


async def backfill(db, dry_run):
    client = _client()
    restaurants = [r for r in db.query(DBRestaurant).order_by(DBRestaurant.id).all() if cuisine_of(r.primary_type) is None]
    print(f"Checking {len(restaurants)} restaurants with no cuisine type...")

    updated, unmapped, failed = [], [], []
    for restaurant in restaurants:
        try:
            new_type, types = await fetch_type(client, restaurant.place_id)
        except ResourceExhausted:  # daily quota used up, so every remaining request would fail too
            print("Google quota used up for today - stopping early. Run again later to finish.")
            break
        except Exception as error:  # one bad place shouldn't stop the whole run
            failed.append((restaurant.name, str(error).splitlines()[0]))
            continue

        if new_type and new_type != restaurant.primary_type:
            print(f"  {restaurant.name}: {restaurant.primary_type!r} -> {new_type!r}")
            updated.append(restaurant.name)
            if not dry_run:
                restaurant.primary_type = new_type
        if cuisine_of(new_type) is None:
            unmapped.append((restaurant.name, new_type, types))

    print(f"\n{'Would update' if dry_run else 'Updated'}: {len(updated)}")
    print(f"Still no cuisine: {len(unmapped)}")
    for name, place_type, types in unmapped:
        print(f"  {name}: {place_type!r} {types}")
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
