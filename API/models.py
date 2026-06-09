from pydantic import BaseModel
from typing import Optional

class User(BaseModel):
    username: str
    email: Optional[str] = None
    full_name: Optional[str] = None
    disabled: Optional[bool] = None

class UserInDB(User):
    hashed_password: str

class UserCreate(BaseModel):
    username: str
    email: str
    full_name: str
    password: str

class UserForm(BaseModel):
    username: str
    password: str

class UserInformation(BaseModel):
    lat: float
    lng: float
    radius: int
    time: str
    
    