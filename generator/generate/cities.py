import random
import pandas as pd
from generator.faker_utils import fake
from generator.generate.utils import save_to_csv
from generator.config import CITIES_COUNT

def generate_cities(countries_df):
    countries = countries_df.to_dict(orient="records")
    cities = []
    seen = set()
    
    # 1. Guarantee at least 1 city per country
    city_id = 1
    for country in countries:
        c_id = country["id"]
        # Generate a city name
        city_name = fake.city()
        state = fake.state() if random.random() > 0.3 else ""
        
        key = (c_id, city_name, state)
        # Avoid duplicate key issues
        attempts = 0
        while key in seen and attempts < 100:
            city_name = fake.city()
            state = fake.state() if random.random() > 0.3 else ""
            key = (c_id, city_name, state)
            attempts += 1
            
        seen.add(key)
        cities.append({
            "id": city_id,
            "country_id": c_id,
            "name": city_name,
            "state_province": state if state else None
        })
        city_id += 1
        
    # 2. Distribute the remaining 700 cities
    # We assign higher weights to larger economies (e.g. US, BR, CN, IN, DE, GB, FR, JP)
    weighted_countries = []
    high_weight_codes = {"US", "BR", "CN", "IN", "DE", "GB", "FR", "JP", "MX", "CA", "ES", "RU", "AU", "ZA"}
    
    for country in countries:
        weight = 10 if country["code"] in high_weight_codes else 1
        weighted_countries.extend([country] * weight)
        
    remaining = CITIES_COUNT - len(cities)
    for _ in range(remaining):
        country = random.choice(weighted_countries)
        c_id = country["id"]
        
        city_name = fake.city()
        state = fake.state() if random.random() > 0.3 else ""
        key = (c_id, city_name, state)
        
        attempts = 0
        while key in seen and attempts < 100:
            city_name = fake.city()
            state = fake.state() if random.random() > 0.3 else ""
            key = (c_id, city_name, state)
            attempts += 1
            
        seen.add(key)
        cities.append({
            "id": city_id,
            "country_id": c_id,
            "name": city_name,
            "state_province": state if state else None
        })
        city_id += 1
        
    df = pd.DataFrame(cities)
    save_to_csv(df, "cities.csv")
    return df

if __name__ == "__main__":
    # Test stub
    from generator.generate.countries import generate_countries
    countries_df = generate_countries()
    generate_cities(countries_df)
