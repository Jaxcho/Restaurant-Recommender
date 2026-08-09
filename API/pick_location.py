import requests

def geocode(address):
    r = requests.get("https://nominatim.openstreetmap.org/search", params={
        "q": address, "format": "json", "limit": 1
    }, headers={"User-Agent": "MyApp/1.0"})
    if r.json():
        result = r.json()[0]
        return {"lat": result["lat"], "lon": result["lon"], "display": result["display_name"]}
    return None

if __name__ == "__main__":
    print(geocode("Eiffel Tower, Paris"))
