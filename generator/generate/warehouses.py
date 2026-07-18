import random
import pandas as pd
from generator.faker_utils import fake
from generator.generate.utils import save_to_csv
from generator.config import WAREHOUSES_COUNT

def generate_warehouses(cities_df):
    # To keep warehouses in major locations, let's select cities from countries like 
    # US, BR, CN, IN, DE, GB, FR, JP.
    # We can join with countries or just take cities that are high up in cities_df (first 80, which are distributed).
    # Actually, let's pick 8 distinct cities from the cities dataframe.
    # To ensure they are major countries, we can select cities whose country_id corresponds to the first 15 countries.
    major_cities = cities_df[cities_df["country_id"] <= 15].to_dict(orient="records")
    chosen_cities = random.sample(major_cities, WAREHOUSES_COUNT)
    
    warehouse_names = [
        "Global Gateway Hub",
        "Americas Logistics Center",
        "Euro Hub Frankfurt",
        "Asia-Pacific Depot",
        "Andean Distribution Center",
        "North Sea Storage",
        "Mediterranean Gateway",
        "Atlantic Express Depot"
    ]
    
    warehouses = []
    for i in range(1, WAREHOUSES_COUNT + 1):
        city = chosen_cities[i-1]
        warehouses.append({
            "id": i,
            "city_id": city["id"],
            "name": warehouse_names[i-1],
            "address": fake.street_address(),
            "capacity": random.choice([500000, 750000, 1000000, 1500000])
        })
        
    df = pd.DataFrame(warehouses)
    save_to_csv(df, "warehouses.csv")
    return df

if __name__ == "__main__":
    from generator.generate.countries import generate_countries
    from generator.generate.cities import generate_cities
    co = generate_countries()
    ci = generate_cities(co)
    generate_warehouses(ci)
