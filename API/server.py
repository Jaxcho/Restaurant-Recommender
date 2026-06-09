import asyncio
import uvicorn
from fastapi import FastAPI, Depends, HTTPException, status, Response, Request
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta
from sqlalchemy.orm import Session
from location import nearby_search
from auth import (authenticate_user, create_access_token, get_current_active_user, fake_users_db, ACCESS_TOKEN_EXPIRE_MINUTES, get_password_hash, decode_token, token_validation)
from database import DBUser, get_db
from models import User, UserCreate, UserForm, UserInformation
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Authentication Demo", version="1.0.0")

app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

@app.post("/find_restaurants")
async def find_restaurants(user_information: UserInformation, response: Response):
    lat = user_information.lat
    lng = user_information.lng
    radius = user_information.radius*1609.344
    time = user_information.time
    
    return await nearby_search(lat, lng, radius)
    
@app.get("/")
async def root():
    return {"message": "Welcome to FastAPI Authentication Demo"}

@app.post("/refresh")
async def refresh_token(response: Response, request: Request,  db: Session = Depends(get_db)):
    """Authenticate user and return access token."""
    
    token = request.cookies.get('refresh_token')
    if token == None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    username = decode_token(token)

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": username}, expires_delta=access_token_expires
    )
    refresh_token = create_access_token(data={"sub": username}, expires_delta=timedelta(minutes=10080))
    response.set_cookie(key = "refresh_token", path = "/", httponly = True, secure = True, value = refresh_token)

    return {"access_token": access_token, "token_type": "bearer"}



@app.get("/users/me", response_model=User)
async def read_users_me(current_user: User = Depends(get_current_active_user)):
    """Get current user information."""
    return current_user

@app.get("/protected/{name}")
# async def protected_route(current_user: User = Depends(get_current_active_user)):
#     return {"message": f"Hello {current_user.full_name}, this is a protected route!"}
async def protected_route(name: str, is_authenticated: bool = Depends(token_validation)):
    if(is_authenticated == True):
        return f"Hi {name}"
    return is_authenticated

@app.post("/auth/register")
def create_user(response: Response, user: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(DBUser).filter(DBUser.username == user.username).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Username already exists")

    db_user = DBUser(
        username=user.username,
        email=user.email,
        full_name=user.full_name,
        hashed_password=get_password_hash(user.password)
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": db_user.username}, expires_delta=access_token_expires
    )
    refresh_token = create_access_token(data={"sub": db_user.username}, expires_delta=timedelta(minutes=10080))
    response.set_cookie(key = "refresh_token", path = "/", httponly = True, secure = True, value = refresh_token)

    return {"access_token": access_token, "token_type": "bearer"}


@app.post("/auth/login")
def login_user(user: UserForm, response: Response, db: Session = Depends(get_db)):
    existing_user = db.query(DBUser).filter(DBUser.username == user.username).first()
    if not existing_user:
        raise HTTPException(status_code=404, detail="User not found")
    user = authenticate_user(db, user.username, user.password)
    if not user:
        raise HTTPException(status_code=401, detail="Unauthorized")

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    refresh_token = create_access_token(data={"sub": user.username}, expires_delta=timedelta(minutes=10080))
    response.set_cookie(key = "refresh_token", path = "/", httponly = True, secure = True, value = refresh_token)

    return {"access_token": access_token, "token_type": "bearer"}





#todo:
#send requests through postman
#make auth
#check if it went through by using postgres admin and query through users table


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
    # uvicorn.run("app", host="0.0.0.0", port=8000)






# """ Follow this guide:

# https://betterstack.com/community/guides/scaling-python/authentication-fastapi/
# """