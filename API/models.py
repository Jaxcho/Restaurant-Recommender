from pydantic import BaseModel, Field
from typing import Optional
from datetime import date

class VisitedRestaurant(BaseModel):
    place_id: str
    date_visited: date

class User(BaseModel):
    username: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    disabled: Optional[bool] = None

class UserInDB(User):
    hashed_password: str

class UserCreate(BaseModel):
    username: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    password: str

class UserForm(BaseModel):
    username: str
    password: str

class UserInformation(BaseModel):
    lat: float
    lng: float
    radius: float
    time: str

class PickLocation(BaseModel):
    address: str
    radius: float

class RestaurantRating(BaseModel):
    place_id: str
    rating: float
    content: str

class AverageRatings(BaseModel):
    restaurant: str
    rating: float

class Autocomplete(BaseModel):
    text: str

class Hours(BaseModel):
    place_id: str
class Recommend(BaseModel):
    place_ids: list[str]
    # Optional context from the phone; old clients send only place_ids
    lat: Optional[float] = Field(default=None, ge=-90, le=90)     # search center
    lng: Optional[float] = Field(default=None, ge=-180, le=180)
    day: Optional[int] = Field(default=None, ge=0, le=6)          # phone's local time, 0 = Sunday like Google's hours
    hour: Optional[int] = Field(default=None, ge=0, le=23)
    minute: Optional[int] = Field(default=None, ge=0, le=59)

class Taste(BaseModel):
    key: str    # a CUISINES key, e.g. "fast_food"
    score: int  # -1 not for me, 0 okay, 1 love it

class Preferences(BaseModel):
    tastes: list[Taste]  # a list, not a dict, so the app's snake_case decoder can't rename the keys

class WantToGo(BaseModel):
    place_id: str
