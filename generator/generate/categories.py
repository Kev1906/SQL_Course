import pandas as pd
from generator.generate.utils import save_to_csv

def generate_categories():
    # 30 categories arranged hierarchically
    categories_data = [
        # Level 1 (Parents - 10)
        (1, None, "Electronics", "Devices, gadgets, and hardware accessories"),
        (2, None, "Apparel", "Clothing, garments, footwear, and accessories"),
        (3, None, "Home & Kitchen", "Furniture, kitchen appliances, and home decor"),
        (4, None, "Sports & Outdoors", "Athletic gear, fitness equipment, and outdoor apparel"),
        (5, None, "Beauty & Personal Care", "Cosmetics, skincare, hair care, and grooming"),
        (6, None, "Books", "Physical books, e-books, and audiobooks"),
        (7, None, "Toys & Games", "Toys, board games, and video games for all ages"),
        (8, None, "Automotive", "Car accessories, parts, and tools"),
        (9, None, "Grocery & Gourmet Food", "Pantry staples, fresh foods, and beverages"),
        (10, None, "Office Products", "Stationery, office furniture, and school supplies"),
        
        # Level 2 (Subcategories of Electronics - 1)
        (11, 1, "Smartphones", "Mobile phones and cellular devices"),
        (12, 1, "Laptops & Computers", "Personal computers, notebooks, and tablets"),
        (13, 1, "Audio & Headphones", "Speakers, headphones, and audio equipment"),
        (14, 1, "Smart Home Devices", "Smart plugs, bulbs, and home voice assistants"),
        
        # Level 2 (Subcategories of Apparel - 2)
        (15, 2, "Men's Fashion", "Clothing, shoes, and accessories for men"),
        (16, 2, "Women's Fashion", "Clothing, dresses, and accessories for women"),
        (17, 2, "Footwear & Shoes", "Shoes, boots, sneakers, and sandals"),
        
        # Level 2 (Subcategories of Home & Kitchen - 3)
        (18, 3, "Kitchen Appliances", "Blenders, coffee makers, and cooking equipment"),
        (19, 3, "Furniture", "Beds, sofas, desks, and chairs"),
        (20, 3, "Bedding & Bath", "Sheets, pillows, towels, and bath accessories"),
        
        # Level 2 (Subcategories of Sports & Outdoors - 4)
        (21, 4, "Fitness & Gym", "Dumbbells, yoga mats, and exercise machines"),
        (22, 4, "Outdoor Recreation", "Camping gear, tents, and hiking accessories"),
        (23, 4, "Cycling & Bikes", "Bicycles, helmets, and cycling gear"),
        
        # Level 2 (Subcategories of Beauty - 5)
        (24, 5, "Makeup & Cosmetics", "Foundation, lipstick, and eye makeup"),
        (25, 5, "Skin Care", "Moisturizers, cleansers, and sunscreens"),
        
        # Level 2 (Subcategories of Toys - 7)
        (26, 7, "Board Games", "Strategy, family, and party board games"),
        (27, 7, "Action Figures & Dolls", "Collectible action figures and dolls"),
        
        # Level 2 (Subcategories of Automotive - 8)
        (28, 8, "Car Care", "Car wax, soaps, and cleaning accessories"),
        
        # Level 2 (Subcategories of Grocery - 9)
        (29, 9, "Beverages", "Coffee, tea, sodas, and juices"),
        (30, 9, "Snacks & Sweets", "Chips, cookies, and chocolates")
    ]
    
    # Confirm count is exactly 30
    assert len(categories_data) == 30, f"Expected 30 categories, got {len(categories_data)}"
    
    df = pd.DataFrame(categories_data, columns=["id", "parent_id", "name", "description"])
    df["parent_id"] = df["parent_id"].astype("Int64")
    save_to_csv(df, "categories.csv")
    return df

if __name__ == "__main__":
    generate_categories()
