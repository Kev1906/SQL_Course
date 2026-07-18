import random
import json
import pandas as pd
from generator.faker_utils import fake, generate_sku
from generator.generate.utils import save_to_csv
from generator.config import PRODUCTS_COUNT

def generate_products(categories_df, suppliers_df):
    categories = categories_df.to_dict(orient="records")
    suppliers = suppliers_df.to_dict(orient="records")
    
    # Pre-map categories to parent details for fast lookup
    cat_by_id = {c["id"]: c for c in categories}
    
    # Group suppliers by category focus (e.g., 'Electronics', 'Apparel')
    suppliers_by_focus = {}
    for s in suppliers:
        focus = s["category_focus"]
        if focus not in suppliers_by_focus:
            suppliers_by_focus[focus] = []
        suppliers_by_focus[focus].append(s)
        
    products = []
    
    # Price boundaries by parent category
    category_price_rules = {
        "Electronics": (20.00, 2000.00),
        "Apparel": (10.00, 200.00),
        "Home & Kitchen": (15.00, 800.00),
        "Sports & Outdoors": (5.00, 500.00),
        "Beauty & Personal Care": (5.00, 150.00),
        "Books": (8.00, 80.00),
        "Toys & Games": (10.00, 120.00),
        "Automotive": (5.00, 300.00),
        "Grocery & Gourmet Food": (2.00, 50.00),
        "Office Products": (1.00, 100.00)
    }
    
    brands = {
        "Electronics": ["TechCo", "Sonyx", "Volt", "Quant", "LinkSys", "AudioMax"],
        "Apparel": ["ThreadWear", "Vogue", "ActiveFit", "DenimCo", "UrbanStyle"],
        "Home & Kitchen": ["KitchenAid", "DecoHome", "CozyLiving", "ChefChoice"],
        "Sports & Outdoors": ["PeakGear", "TrailBlaze", "FitPulse", "AquaFlow"],
        "Beauty & Personal Care": ["GlowUp", "SilkSkin", "HerbEssentials", "LuxeHair"],
        "Books": ["Penguin", "Harper", "OReilly", "Packt", "Springer"],
        "Toys & Games": ["PlayTime", "BrickBuilder", "BoardFun", "KidZone"],
        "Automotive": ["AutoPro", "DriveClean", "MotorMax", "TireSafe"],
        "Grocery & Gourmet Food": ["OrganicWay", "TastyBites", "NatureDrop", "SweetTreats"],
        "Office Products": ["PaperMate", "OfficePro", "StapleMax", "DeskWork"]
    }
    
    colors = ["Black", "White", "Silver", "Gray", "Red", "Blue", "Green", "Yellow", "Pink", "Navy"]
    sizes = ["XS", "S", "M", "L", "XL", "XXL"]
    materials = ["Cotton", "Polyester", "Wool", "Leather", "Metal", "Plastic", "Wood", "Glass"]
    
    for i in range(1, PRODUCTS_COUNT + 1):
        # Pick category
        cat = random.choice(categories)
        cat_id = cat["id"]
        cat_name = cat["name"]
        
        # Resolve parent category
        parent_cat = cat
        while parent_cat["parent_id"] is not None and pd.notna(parent_cat["parent_id"]):
            parent_cat = cat_by_id[int(parent_cat["parent_id"])]
        parent_name = parent_cat["name"]
        
        # Pick supplier that focuses on this parent category
        candidates = suppliers_by_focus.get(parent_name, suppliers)
        supplier = random.choice(candidates)
        supplier_id = supplier["id"]
        
        # Generate price & cost
        price_range = category_price_rules.get(parent_name, (10.00, 100.00))
        price = round(random.uniform(price_range[0], price_range[1]), 2)
        # Cost is between 40% and 75% of price
        cost = round(price * random.uniform(0.40, 0.75), 2)
        
        # Generate name
        prod_noun = fake.word().capitalize()
        prod_adj = random.choice(["Premium", "Ultra", "Classic", "Pro", "Smart", "Eco", "Deluxe"])
        name = f"{prod_adj} {parent_name.split('&')[0].strip()} {prod_noun}"
        
        # Generate SKU
        sku = generate_sku(cat_name, i)
        
        # Generate JSONB Attributes
        brand = random.choice(brands.get(parent_name, ["Universal"]))
        attrs = {"brand": brand}
        
        if parent_name == "Electronics":
            attrs.update({
                "color": random.choice(colors),
                "weight_kg": round(random.uniform(0.1, 8.0), 2),
                "warranty_years": random.choice([1, 2, 3, 5])
            })
        elif parent_name == "Apparel":
            attrs.update({
                "color": random.choice(colors),
                "size": random.choice(sizes),
                "material": random.choice(materials)
            })
        elif parent_name in ["Home & Kitchen", "Sports & Outdoors"]:
            attrs.update({
                "material": random.choice(materials),
                "weight_kg": round(random.uniform(0.5, 25.0), 2)
            })
        elif parent_name == "Grocery & Gourmet Food":
            attrs.update({
                "organic": random.choice([True, False]),
                "expiration_days": random.randint(10, 365)
            })
        else:
            attrs.update({
                "weight_g": random.randint(50, 1500)
            })
            
        products.append({
            "id": i,
            "category_id": cat_id,
            "supplier_id": supplier_id,
            "name": name,
            "sku": sku,
            "price": price,
            "cost": cost,
            "description": f"High quality {name.lower()} from {brand}.",
            "attributes": json.dumps(attrs), # Dump as json string for CSV COPY
            "is_active": True
        })
        
    df = pd.DataFrame(products)
    save_to_csv(df, "products.csv")
    return df

if __name__ == "__main__":
    from generator.generate.countries import generate_countries
    from generator.generate.cities import generate_cities
    from generator.generate.categories import generate_categories
    from generator.generate.suppliers import generate_suppliers
    co = generate_countries()
    ci = generate_cities(co)
    ca = generate_categories()
    su = generate_suppliers(ci, ca)
    generate_products(ca, su)
stream = True
