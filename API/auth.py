from datetime import datetime, timedelta
from typing import Optional
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt, ExpiredSignatureError, JWTError
from models import User, UserInDB
from datetime import datetime, timedelta, timezone
from typing import Optional
from passlib.context import CryptContext
from database import DBUser


# Configuration
SECRET_KEY = "your-secret-key-here"  # In production, use environment variables
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Password hashing context
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Fake database - replace with real database in production
fake_users_db = {
    "johndoe": {
        "username": "johndoe",
        "full_name": "John Doe",
        "email": "johndoe@example.com",
        "hashed_password": "$pbkdf2-sha256$29000$qhUiBAAgpPT.f0.JUSpFyA$TD1OcklXZ8nO/jrBMbzpCyqrbaTgRgxcXZ5KF/TKXLQ",  # secret
        "disabled": False,
    }
}

def decode_token(token):
    decoded = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    return decoded["sub"]

def verify_password(plain_password, hashed_password):
    """Verify a password against its hash."""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    """Generate a hash for a password."""
    return pwd_context.hash(password)

def get_user(db, username: str):
    """Get a user from the database."""
    existing_user = db.query(DBUser).filter(DBUser.username == username).first()
    return existing_user

def authenticate_user(db, username: str, password: str):
    """Check if username and password are correct."""
    user = get_user(db, username)
    if not user:
        return False
    if not verify_password(password, user.hashed_password):
        return False
    return user

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create a JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)

    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

...

async def get_current_user(db, token: str = Depends(oauth2_scheme)):
    """Get the current user from the JWT token."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = get_user(db, username=username)
    if user is None:
        raise credentials_exception
    return user

async def get_current_active_user(current_user: User = Depends(get_current_user)):
    """Get the current active user (not disabled)."""
    if current_user.disabled:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

# @app.middleware('http')
async def token_validation(req: Request):
# async def token_validation(token: str = Depends(oauth2_scheme)):
    try:
        token = req.headers["x-access-token"]
        try:
            jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            # await call_next()
            return True
        except (ExpiredSignatureError, JWTError):
            return HTTPException(status_code=403, detail="Invalid token")
    except KeyError:
        return HTTPException(status_code=400, detail="Bad request")




"""TODO
Add a helper function for protected routes, gets used on authorization requiring funcs
    - is access token expired or still valid?
        - if invalid, return 403
        - if valid return 200
"""