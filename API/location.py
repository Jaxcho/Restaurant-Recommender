import asyncio
from google.maps import places_v1
from google.type import latlng_pb2
from geopy.distance import geodesic

async def find_autocomplete(input_text):
    client = places_v1.PlacesAsyncClient(client_options={"api_key": "AIzaSyDlTtqGqM5cy9S8AeK5mtX5UgBxWIFeoDE"})

    # No location bias — search the entire world.
    request = places_v1.AutocompletePlacesRequest(input=input_text)
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