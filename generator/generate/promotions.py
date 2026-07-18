import random
import pandas as pd
from datetime import datetime, timedelta
from generator.generate.utils import save_to_csv

def generate_promotions_and_coupons():
    # 1. Generate 10 promotions
    promotions_data = [
        {"id": 1, "name": "Summer Clearance 2023", "discount_percentage": 15.00, "start_date": "2023-06-01", "end_date": "2023-08-31"},
        {"id": 2, "name": "Black Friday 2023", "discount_percentage": 25.00, "start_date": "2023-11-20", "end_date": "2023-11-27"},
        {"id": 3, "name": "Christmas Super Sale 2023", "discount_percentage": 20.00, "start_date": "2023-12-15", "end_date": "2023-12-31"},
        {"id": 4, "name": "New Year Kickoff 2024", "discount_percentage": 10.00, "start_date": "2024-01-01", "end_date": "2024-01-15"},
        {"id": 5, "name": "Spring Renewal 2024", "discount_percentage": 12.00, "start_date": "2024-03-20", "end_date": "2024-04-10"},
        {"id": 6, "name": "Summer Clearance 2024", "discount_percentage": 15.00, "start_date": "2024-06-01", "end_date": "2024-08-31"},
        {"id": 7, "name": "Black Friday 2024", "discount_percentage": 30.00, "start_date": "2024-11-25", "end_date": "2024-12-02"},
        {"id": 8, "name": "Christmas Super Sale 2024", "discount_percentage": 20.00, "start_date": "2024-12-15", "end_date": "2024-12-31"},
        {"id": 9, "name": "Spring Renewal 2025", "discount_percentage": 15.00, "start_date": "2025-03-20", "end_date": "2025-04-10"},
        {"id": 10, "name": "Summer Special 2025", "discount_percentage": 18.00, "start_date": "2025-06-01", "end_date": "2025-08-31"}
    ]
    
    promotions_df = pd.DataFrame(promotions_data)
    save_to_csv(promotions_df, "promotions.csv")
    
    # 2. Generate 50 coupons
    coupons = []
    coupon_codes = [
        "WELCOME10", "SAVE20", "LOYALTY15", "FREESHIP", "DISCOUNT5", 
        "SUPERDEAL", "BMS10", "FLASH25", "OFFER50", "COUPON12"
    ]
    
    # Generate 50 unique coupons
    for i in range(1, 51):
        # Pick promo to link to optionally (first 20 coupons linked to promotions, next 30 stand-alone)
        promo_id = random.choice(range(1, 11)) if i <= 20 else None
        
        # Pick code base
        base_code = random.choice(coupon_codes)
        code = f"{base_code}-{i:03d}"
        
        discount = random.choice([5.00, 10.00, 15.00, 20.00, 25.00, 50.00])
        min_purchase = discount * random.choice([3, 4, 5])
        
        # is_active
        is_active = random.random() > 0.15 # 85% active
        
        coupons.append({
            "id": i,
            "promotion_id": promo_id,
            "code": code,
            "discount_amount": discount,
            "min_purchase_amount": min_purchase,
            "is_active": is_active
        })
        
    coupons_df = pd.DataFrame(coupons)
    coupons_df["promotion_id"] = coupons_df["promotion_id"].astype("Int64")
    save_to_csv(coupons_df, "coupons.csv")
    
    return promotions_df, coupons_df

if __name__ == "__main__":
    generate_promotions_and_coupons()
