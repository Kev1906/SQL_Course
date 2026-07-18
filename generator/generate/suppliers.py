import random
import pandas as pd
from generator.faker_utils import fake, generate_phone
from generator.generate.utils import save_to_csv
from generator.config import SUPPLIERS_COUNT

def generate_suppliers(cities_df, categories_df):
    city_ids = cities_df["id"].tolist()
    # Focus categories: use parent category names (parent_id is null)
    focus_categories = categories_df[categories_df["parent_id"].isna()]["name"].tolist()
    
    suppliers = []
    seen_names = set()
    
    for i in range(1, SUPPLIERS_COUNT + 1):
        name = fake.company()
        attempts = 0
        while name in seen_names and attempts < 100:
            name = fake.company()
            attempts += 1
        seen_names.add(name)
        
        contact = fake.name()
        email = f"contact@{name.lower().replace(' ', '').replace(',', '').replace('.', '')[:15]}.com"
        
        suppliers.append({
            "id": i,
            "city_id": random.choice(city_ids),
            "name": name,
            "contact_name": contact,
            "email": email,
            "phone": generate_phone(),
            "category_focus": random.choice(focus_categories)
        })
        
    df = pd.DataFrame(suppliers)
    save_to_csv(df, "suppliers.csv")
    return df

if __name__ == "__main__":
    from generator.generate.countries import generate_countries
    from generator.generate.cities import generate_cities
    from generator.generate.categories import generate_categories
    co = generate_countries()
    ci = generate_cities(co)
    ca = generate_categories()
    generate_suppliers(ci, ca)
