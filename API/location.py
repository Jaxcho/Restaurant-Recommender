import asyncio
import math
from google.maps import places_v1
from google.type import latlng_pb2
from geopy.distance import geodesic

async def find_autocomplete(input_text, lat, lng, radius):
    client = places_v1.PlacesAsyncClient(client_options={"api_key": "AIzaSyDlTtqGqM5cy9S8AeK5mtX5UgBxWIFeoDE"})

    kwargs = {"input": input_text}
    if lat is not None and lng is not None:
        center_point = latlng_pb2.LatLng(latitude=lat, longitude=lng)
        circle_area = places_v1.types.Circle(center=center_point, radius=radius)
        kwargs["location_bias"] = places_v1.AutocompletePlacesRequest.LocationBias(circle=circle_area)

    request = places_v1.AutocompletePlacesRequest(**kwargs)
    response = await client.autocomplete_places(request=request)

    return [
        {"place_id": s.place_prediction.place_id, "text": s.place_prediction.text.text}
        for s in response.suggestions
    ]


async def nearby_search(lat, lng, radius):
 
  center_point = latlng_pb2.LatLng(latitude = lat, longitude = lng)
  circle_area = places_v1.types.Circle(
    center = center_point,
    radius = radius)
  location_restriction = places_v1.SearchNearbyRequest.LocationRestriction(
    circle =circle_area
  )
  client = places_v1.PlacesAsyncClient(client_options={"api_key": "AIzaSyDlTtqGqM5cy9S8AeK5mtX5UgBxWIFeoDE"})
  request = places_v1.SearchNearbyRequest(
      location_restriction = location_restriction,
      included_types = ["restaurant"] 
  )

  fieldMask = "places.id,places.displayName"
  response = await client.search_nearby(request=request, metadata=[("x-goog-fieldmask",fieldMask)]) 
  response = jsonify(response)
  
  return response


def meters_to_latlng_offset(meters, lat):
  dlat = meters / 111320
  dlng = meters / (111320 * math.cos(math.radians(lat)))
  return dlat, dlng


async def adaptive_search(lat, lng, radius, min_radius=150, max_depth=4, depth=0):
  results = await nearby_search(lat, lng, radius)

  if len(results) < 20 or radius <= min_radius or depth >= max_depth:
    return results

  sub_radius = radius / 2
  offset = sub_radius / (2 ** 0.5)
  dlat, dlng = meters_to_latlng_offset(offset, lat)

  sub_centers = [
      (lat + dlat, lng + dlng), (lat + dlat, lng - dlng),
      (lat - dlat, lng + dlng), (lat - dlat, lng - dlng),
  ]

  batches = await asyncio.gather(*(
      adaptive_search(c_lat, c_lng, sub_radius, min_radius, max_depth, depth + 1)
      for c_lat, c_lng in sub_centers
  ))

  seen = {}
  for batch in batches:
    for place in batch:
      seen[place["id"]] = place
  return list(seen.values())


async def text_search(query, lat, lng, radius):

  center_point = latlng_pb2.LatLng(latitude = lat, longitude = lng)
  circle_area = places_v1.types.Circle(
    center = center_point,
    radius = radius)
  location_bias = places_v1.SearchTextRequest.LocationBias(
    circle = circle_area
  )
  client = places_v1.PlacesAsyncClient(client_options={"api_key": "AIzaSyDlTtqGqM5cy9S8AeK5mtX5UgBxWIFeoDE"})
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


async def place_details(restaurant_id, lat, lng):
  distance = 0
  final = []
  client = places_v1.PlacesAsyncClient(client_options={"api_key": "AIzaSyDlTtqGqM5cy9S8AeK5mtX5UgBxWIFeoDE"})
  # Build the request
  # request = places_v1.GetPlaceRequest(
  #     name="places/ChIJaXQRs6lZwokRY6EFpJnhNNE",
  # )
  request = places_v1.GetPlaceRequest(
      name = f"places/{restaurant_id}", 
  )
  # Set the field mask
  # fieldMask = "formattedAddress,displayName"
  fieldMask = "displayName,reviewSummary,location,currentOpeningHours"
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
    current_opening_hours.append({"open": open_hour})
    current_opening_hours.append({"close": close_hour})
  
  point = (lat, lng)
  location = [response.location.latitude, response.location.longitude]
  distance = geodesic(point, location).miles
  # print(review_summary)
  return { "review_summary": review_summary, "current_opening_hours" : current_opening_hours,  "location" : location, "name":name, "distance": distance}
  # for val in response.places:
  #     final.append({id})
  return response

# print("Hello 1 from Location.py")
if __name__ == "__main__":
#   # print("Hello 2 from Location.py")
# # print(asyncio.run(place_details()))
  print(asyncio.run(nearby_search(37.783, -122.462, 50)))