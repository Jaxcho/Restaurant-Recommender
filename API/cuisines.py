"""Cuisine choices for the taste profile, mapped to Google Places primary types."""
import json

# key -> (label shown in the app, Google primary types that count as this cuisine)
CUISINES = {
    "american": ("American", {"american_restaurant", "hamburger_restaurant", "barbecue_restaurant", "steak_house", "diner", "californian_restaurant", "brewpub", "bar_and_grill"}),
    "chinese": ("Chinese", {"chinese_restaurant", "dim_sum_restaurant", "hot_pot_restaurant", "chinese_noodle_restaurant", "cantonese_restaurant", "taiwanese_restaurant"}),
    "japanese": ("Japanese", {"japanese_restaurant", "ramen_restaurant", "sushi_restaurant", "japanese_izakaya_restaurant", "japanese_curry_restaurant"}),
    "korean": ("Korean", {"korean_restaurant", "korean_barbecue_restaurant"}),
    "southeast_asian": ("Southeast Asian", {"thai_restaurant", "vietnamese_restaurant", "indonesian_restaurant", "burmese_restaurant"}),
    "indian": ("Indian", {"indian_restaurant"}),
    "latin": ("Mexican & Latin", {"mexican_restaurant", "brazilian_restaurant", "peruvian_restaurant"}),
    "italian": ("Italian & Pizza", {"italian_restaurant", "pizza_restaurant"}),
    "mediterranean": ("Mediterranean", {"mediterranean_restaurant", "greek_restaurant", "middle_eastern_restaurant", "lebanese_restaurant", "turkish_restaurant", "israeli_restaurant", "falafel_restaurant"}),
    "brunch": ("Breakfast & Brunch", {"breakfast_restaurant", "brunch_restaurant", "bakery", "cafe", "coffee_shop", "dessert_shop", "donut_shop", "bagel_shop", "tea_house"}),
    "fast_food": ("Fast Food", {"fast_food_restaurant", "sandwich_shop"}),
    "seafood": ("Seafood", {"seafood_restaurant"}),
    "vegetarian": ("Vegetarian", {"vegetarian_restaurant", "vegan_restaurant"}),
}

# "_restaurant" types too broad to name a cuisine, so Google's other types are worth checking.
BROAD_RESTAURANT_TYPES = {"asian_restaurant", "family_restaurant", "fine_dining_restaurant", "buffet_restaurant"}


def cuisine_of(primary_type):
    """The cuisine key this Google type belongs to, or None."""
    for key, (_, types) in CUISINES.items():
        if primary_type in types:
            return key
    return None


def resolve_type(primary_type, types):
    """The most useful type for a place: its primary type if it names a cuisine (even one we don't cover, like
    french_restaurant), else the first cuisine in Google's full `types` list (rescues vague ones like "restaurant")."""
    if cuisine_of(primary_type):
        return primary_type
    if primary_type and primary_type.endswith("_restaurant") and primary_type not in BROAD_RESTAURANT_TYPES:
        return primary_type  # don't guess "American" for a French place just because "diner" is in its types
    for place_type in types:
        if cuisine_of(place_type):
            return place_type
    return primary_type


def parse_tastes(food_preferences):
    """Stored taste profile JSON -> {cuisine_key: score}. Old rows stored a plain list of liked keys."""
    if not food_preferences:
        return {}
    tastes = json.loads(food_preferences)
    if isinstance(tastes, list):
        return {key: 1 for key in tastes}
    return tastes
