import asyncio
from google.maps import places_v1
from google.type import latlng_pb2

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


def jsonify(data):
  response = []


  for place in data.places:
    response.append({"id": place.id, "name" : place.display_name.text})
  
  return response


async def place_details():
  client = places_v1.PlacesAsyncClient(client_options={"api_key": "AIzaSyDlTtqGqM5cy9S8AeK5mtX5UgBxWIFeoDE"})
  # Build the request
  # request = places_v1.GetPlaceRequest(
  #     name="places/ChIJaXQRs6lZwokRY6EFpJnhNNE",
  # )
  request = places_v1.SearchNearbyRequest(
      mapping = None, 
  )
  # Set the field mask
  # fieldMask = "formattedAddress,displayName"
  fieldMask = "reviewSummary,regularOpeningHours,rating,priceRange"
  # Make the request
  response = await client.get_place(request=request, metadata=[("x-goog-fieldmask",fieldMask)])
  return response

# print("Hello 1 from Location.py")
if __name__ == "__main__":
#   # print("Hello 2 from Location.py")
# # print(asyncio.run(place_details()))
  print(asyncio.run(nearby_search(37.783, -122.462, 50)))