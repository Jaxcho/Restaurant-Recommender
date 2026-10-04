import asyncio
import os
from dotenv import load_dotenv
from google.maps import places_v1
from google.type import latlng_pb2
from geopy.distance import geodesic
from cuisines import resolve_type

# Reads API/.env when running locally; docker compose passes the same file via env_file.
load_dotenv()
PLACES_API_KEY = os.environ["PLACES_API_KEY"]


def _client():
  return places_v1.PlacesAsyncClient(client_options={"api_key": PLACES_API_KEY})

async def find_autocomplete(input_text):
    client = _client()

    # No location bias — search the entire world.
    request = places_v1.AutocompletePlacesRequest(input=input_text)
    response = await client.autocomplete_places(request=request)

    return [
        {"place_id": s.place_prediction.place_id, "text": s.place_prediction.text.text}
        for s in response.suggestions
    ]


# The hour a meal window starts (inclusive) and ends (exclusive), 24h clock.
MEAL_WINDOWS = {
    "breakfast": (6, 11),
    "lunch": (11, 16),
    "dinner": (16, 22),
}


def meal_availability(periods):
  """Turn a restaurant's opening periods into breakfast/lunch/dinner flags.

  `periods` is a list of {"open": {hour,...}, "close": {hour,...}} dicts. A meal
  is available if any open interval overlaps that meal's window.
  """
  flags = {"breakfast": False, "lunch": False, "dinner": False}
  for period in periods:
    open_side = period.get("open")
    if not open_side:
      continue
    start = open_side["hour"]
    close_side = period.get("close")
    end = close_side["hour"] if close_side else 24
    if end <= start:  # closes after midnight, or open 24h
      end += 24
    for meal, (win_start, win_end) in MEAL_WINDOWS.items():
      if start < win_end and win_start < end:  # intervals overlap
        flags[meal] = True
  return flags


async def nearby_search(lat, lng, radius):

  center_point = latlng_pb2.LatLng(latitude = lat, longitude = lng)
  circle_area = places_v1.types.Circle(
    center = center_point,
    radius = radius)
  location_restriction = places_v1.SearchNearbyRequest.LocationRestriction(
    circle =circle_area
  )
  client = _client()
  request = places_v1.SearchNearbyRequest(
      location_restriction = location_restriction,
      included_types = ["restaurant"]
  )

  fieldMask = "places.id,places.displayName,places.regularOpeningHours,places.location,places.primaryType,places.types"
  response = await client.search_nearby(request=request, metadata=[("x-goog-fieldmask",fieldMask)])

  results = []
  for place in response.places:
    periods = []
    for period in place.regular_opening_hours.periods:
      open_hour = {"day": period.open.day, "hour": period.open.hour, "minute": period.open.minute}
      close_hour = {"day": period.close.day, "hour": period.close.hour, "minute": period.close.minute}
      periods.append({"open": open_hour, "close": close_hour})
    flags = meal_availability(periods)
    results.append({
      "id": place.id,
      "name": place.display_name.text,
      "hours": periods,
      "location": [place.location.latitude, place.location.longitude],
      "primary_type": resolve_type(place.primary_type, list(place.types)),
      **flags,
    })

  return results


async def text_search(query, lat, lng, radius):

  center_point = latlng_pb2.LatLng(latitude = lat, longitude = lng)
  circle_area = places_v1.types.Circle(
    center = center_point,
    radius = radius)
  location_bias = places_v1.SearchTextRequest.LocationBias(
    circle = circle_area
  )
  client = _client()
  request = places_v1.SearchTextRequest(
      text_query = query,
      location_bias = location_bias,
      included_type = "restaurant",
  )

  fieldMask = "places.id,places.displayName"
  response = await client.search_text(request=request, metadata=[("x-goog-fieldmask",fieldMask)])
  response = jsonify(response)

  return response


def jsonify(data):
  response = []


  for place in data.places:
    response.append({"id": place.id, "name" : place.display_name.text})
  
  return response


async def _photo_url(client, photos):
  """Short-lived Google image URL for the first photo, or None. The URL has no API key in it, so it's safe to send to the app."""
  if not photos:
    return None
  try:
    media = await client.get_photo_media(
      request=places_v1.GetPhotoMediaRequest(name=f"{photos[0].name}/media", max_width_px=800, skip_http_redirect=True)
    )
    return media.photo_uri
  except Exception:
    return None  # a missing photo shouldn't break the details sheet


async def place_details(restaurant_id, lat, lng):
  distance = 0
  final = []
  client = _client()
  # Build the request
  # request = places_v1.GetPlaceRequest(
  #     name="places/ChIJaXQRs6lZwokRY6EFpJnhNNE",
  # )
  request = places_v1.GetPlaceRequest(
      name = f"places/{restaurant_id}", 
  )
  # Set the field mask
  # fieldMask = "formattedAddress,displayName"
  fieldMask = "displayName,reviewSummary,location,currentOpeningHours,photos,primaryType,types"
  # Make the request
  response = await client.get_place(request=request, metadata=[("x-goog-fieldmask",fieldMask)])
  review_summary = response.review_summary.text.text
  current_opening_hours = []
  name = response.display_name.text
  for period in response.current_opening_hours.periods:
    open = period.open
    close = period.close
    open_hour = { "day": open.day, "hour": open.hour, "minute": open.minute }
    close_hour = { "day": close.day, "hour": close.hour, "minute": close.minute }
    current_opening_hours.append({"open": open_hour, "close": close_hour})
  
  point = (lat, lng)
  location = [response.location.latitude, response.location.longitude]
  distance = geodesic(point, location).miles
  photo_url = await _photo_url(client, response.photos)
  primary_type = resolve_type(response.primary_type, list(response.types))
  # print(review_summary)
  return { "review_summary": review_summary, "current_opening_hours" : current_opening_hours,  "location" : location, "name":name, "distance": distance, "photo_url": photo_url, "primary_type": primary_type}
  # for val in response.places:
  #     final.append({id})
  return response

# print("Hello 1 from Location.py")
if __name__ == "__main__":
#   # print("Hello 2 from Location.py")
# # print(asyncio.run(place_details()))
  print(asyncio.run(nearby_search(37.783, -122.462, 50)))