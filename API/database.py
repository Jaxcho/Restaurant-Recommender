import os
from sqlalchemy import create_engine, Column, Integer, String, Boolean, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from sqlalchemy.dialects.postgresql import UUID
import uuid

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:changeme@localhost:5432/app"
)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class DBUser(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, index=True, default=uuid.uuid4)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True)
    full_name = Column(String)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)

class DBRestaurant(Base):
    __tablename__ = "restaurants"
    id = Column(Integer, primary_key = True, index = True)
    name = Column(String)
    hours = Column(String)
    location = Column(String)

class DBUserDinedRestaurants(Base):
    __tablename__ = "user_dined_restaurants"
    id = Column(Integer, index = True, primary_key = True)
    user_id = Column(UUID(as_uuid = True), ForeignKey("users.id"), index = True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"), index = True)

class DBReviews(Base):
    __tablename__ = 'reviews'
    id = Column(Integer, index = True, primary_key = True)
    restaurant_id = Column(Integer, ForeignKey("restaurants.id"))
    reviewer_name = Column(String, index = True)
    reviewer_id = Column(UUID(as_uuid = True), ForeignKey("users.id"))
    content = Column(String)

class DBUserPreferences(Base):
    __tablename__ = "user_preferences"
    id = Column(UUID(as_uuid=True), ForeignKey("users.id"), index=True, primary_key=True, default=uuid.uuid4)
    food_preferences = Column(String)
    location = Column(String)

"""

User restaurant data
    What restaurants have the user eaten at
    What type of food do they like
    Location
    Time that they want to eat
    Amount of people they want to eat with
    Take out/ going out maybe?
    Types of restaurants they like; Energetic, or mellow

Reviews; What is their best foods
Restaurant location
Restaurant size
When are they open


"""

# class UserPrefrences(Base):
#     __tablename__ = 'UserPrefrences'
#     id = Column(UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True, index=True)
    





Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()