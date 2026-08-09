from pydantic import BaseModel
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


    
    