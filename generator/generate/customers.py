import random
import pandas as pd
from datetime import datetime, timedelta
from generator.faker_utils import fake, generate_phone
from generator.generate.utils import save_to_csv
from generator.config import CUSTOMERS_COUNT

def generate_customers(cities_df):
    city_ids = cities_df["id"].tolist()
    
    customers = []
    seen_emails = set()
    
    # Customer Segment distribution:
    # 5% Premium, 15% Sports Enthusiast, 40% Occasional, 40% Standard
    segments = ["Premium", "Sports Enthusiast", "Occasional", "Standard"]
    segment_weights = [0.05, 0.15, 0.40, 0.40]
    
    genders = ["Male", "Female", "Other", "Prefer Not to Say"]
    gender_weights = [0.48, 0.48, 0.02, 0.02]
    
    for i in range(1, CUSTOMERS_COUNT + 1):
        segment = random.choices(segments, weights=segment_weights)[0]
        gender = random.choices(genders, weights=gender_weights)[0]
        
        # Gender-specific names
        if gender == "Male":
            fn = fake.first_name_male()
        elif gender == "Female":
            fn = fake.first_name_female()
        else:
            fn = fake.first_name()
            
        ln = fake.last_name()
        
        # Email uniqueness
        email_base = f"{fn.lower()}.{ln.lower()}"
        email_base = "".join(c for c in email_base if c.isalnum() or c == ".")
        email = f"{email_base}@gmail.com"
        
        counter = 1
        while email in seen_emails:
            email = f"{email_base}{counter}@gmail.com"
            counter += 1
        seen_emails.add(email)
        
        # Birth date: Adult check (18-75 years old, adding 30 days to clear leap year boundaries)
        age_days = random.randint(18 * 365 + 30, 75 * 365)
        birth_date = (datetime.now() - timedelta(days=age_days)).strftime("%Y-%m-%d")
        
        is_active = random.random() > 0.05 # 5% inactive rate
        phone = generate_phone() if random.random() > 0.15 else None
        
        customers.append({
            "id": i,
            "city_id": random.choice(city_ids),
            "first_name": fn,
            "last_name": ln,
            "email": email,
            "phone": phone,
            "gender": gender,
            "segment": segment,
            "birth_date": birth_date,
            "is_active": is_active
        })
        
    df = pd.DataFrame(customers)
    save_to_csv(df, "customers.csv")
    return df

if __name__ == "__main__":
    from generator.generate.countries import generate_countries
    from generator.generate.cities import generate_cities
    co = generate_countries()
    ci = generate_cities(co)
    generate_customers(ci)
