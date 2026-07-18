import random
import pandas as pd
from datetime import datetime, timedelta
from generator.generate.utils import save_to_csv
from tqdm import tqdm

def generate_reviews(orders_df, order_items_df, customers_df):
    # Select delivered orders
    delivered_orders = orders_df[orders_df["status"] == "Delivered"].to_dict(orient="records")
    delivered_order_ids = {o["id"]: o for o in delivered_orders}
    
    # Filter customers for segment lookup
    cust_segments = customers_df.set_index("id")["segment"].to_dict()
    
    items = order_items_df[order_items_df["order_id"].isin(delivered_order_ids)].to_dict(orient="records")
    
    reviews = []
    seen_reviews = set()
    review_id = 1
    
    comments = {
        5: [
            "Absolutely fantastic! Exceeded all my expectations.",
            "High quality build, works perfectly.",
            "Super fast shipping and great customer service. 10/10.",
            "Very satisfied. Definitely worth the money.",
            "Best purchase I have made this year!"
        ],
        4: [
            "Very good product, works as advertised.",
            "Good quality. Delivery was slightly delayed but product is solid.",
            "Satisfied with this purchase. Minor wear but looks great.",
            "Solid performance and good value for money."
        ],
        3: [
            "Average quality. It is decent, but nothing special.",
            "Works okay but I expected better material.",
            "It does the job, but there are better alternatives out there.",
            "Decent product but shipping took way too long."
        ],
        2: [
            "Disappointed. The quality feels cheap and plastic.",
            "Did not work as expected. Might return it soon.",
            "Not what I expected based on the pictures. Disappointed."
        ],
        1: [
            "Horrible! Broke on the first day of use.",
            "Waste of money. Complete garbage. Do not buy!",
            "Defective on arrival, and customer service has been unhelpful.",
            "Extremely poor quality. I am returning this immediately."
        ]
    }
    
    print("Generating product reviews based on purchase history...")
    # Stagger reviews: 12% probability of a review per purchased item
    for item in tqdm(items):
        if random.random() > 0.12:
            continue
            
        order_id = item["order_id"]
        prod_id = item["product_id"]
        order_info = delivered_order_ids[order_id]
        cust_id = order_info["customer_id"]
        
        # Check uniqueness constraint uq_customer_product_review
        key = (cust_id, prod_id)
        if key in seen_reviews:
            continue
        seen_reviews.add(key)
        
        segment = cust_segments.get(cust_id, "Standard")
        
        # Rating bias by segment
        if segment == "Premium":
            rating = random.choices([5, 4, 3], weights=[0.70, 0.25, 0.05])[0]
        elif segment == "Occasional":
            rating = random.choices([5, 4, 3, 2, 1], weights=[0.40, 0.30, 0.15, 0.08, 0.07])[0]
        else: # Standard and Sports
            rating = random.choices([5, 4, 3, 2, 1], weights=[0.50, 0.30, 0.10, 0.05, 0.05])[0]
            
        comment = random.choice(comments[rating])
        
        # Review Date: Order Date + 2 to 10 days
        order_date = datetime.strptime(order_info["order_date"], "%Y-%m-%d %H:%M:%S")
        review_date = order_date + timedelta(days=random.randint(2, 10), hours=random.randint(-4, 4))
        review_date_str = review_date.strftime("%Y-%m-%d %H:%M:%S")
        
        reviews.append({
            "id": review_id,
            "customer_id": cust_id,
            "product_id": prod_id,
            "rating": rating,
            "comment": comment,
            "created_at": review_date_str
        })
        review_id += 1
        
    df = pd.DataFrame(reviews)
    save_to_csv(df, "reviews.csv")
    return df

if __name__ == "__main__":
    pass
