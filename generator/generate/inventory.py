import random
import pandas as pd
from datetime import datetime, timedelta
from generator.generate.utils import save_to_csv
from generator.config import STOCKS_COUNT, SEED

def generate_inventory(products_df, warehouses_df):
    products = products_df.to_dict(orient="records")
    warehouses = warehouses_df.to_dict(orient="records")
    
    stocks = []
    movements = []
    
    stock_id = 1
    movement_id = 1
    
    # Establish base date for initial stocking (3 years ago)
    base_date = datetime.now() - timedelta(days=365 * 3)
    
    for w in warehouses:
        w_id = w["id"]
        for p in products:
            p_id = p["id"]
            
            # Coherent stock levels based on price: 
            # expensive items have smaller inventory, cheap items have large inventory
            price = p["price"]
            if price > 500:
                qty = random.randint(5, 20)
                reorder = 5
            elif price > 100:
                qty = random.randint(15, 60)
                reorder = 10
            else:
                qty = random.randint(50, 300)
                reorder = 25
                
            stocks.append({
                "id": stock_id,
                "warehouse_id": w_id,
                "product_id": p_id,
                "quantity": qty,
                "reorder_level": reorder
            })
            
            # Initial INBOUND movement to explain how the stock got there
            # Move date is slightly staggered
            move_date = (base_date + timedelta(days=random.randint(0, 30))).strftime("%Y-%m-%d %H:%M:%S")
            # Random employee between 10 and 100 who checked it in
            emp_id = random.randint(10, 100)
            
            movements.append({
                "id": movement_id,
                "stock_id": stock_id,
                "movement_type": "INBOUND",
                "quantity": qty,
                "reference_id": emp_id,
                "movement_date": move_date
            })
            
            stock_id += 1
            movement_id += 1
            
    assert len(stocks) == STOCKS_COUNT, f"Expected {STOCKS_COUNT} stocks, got {len(stocks)}"
    
    stocks_df = pd.DataFrame(stocks)
    movements_df = pd.DataFrame(movements)
    movements_df["reference_id"] = movements_df["reference_id"].astype("Int64")
    
    save_to_csv(stocks_df, "stocks.csv")
    save_to_csv(movements_df, "movements.csv")
    
    return stocks_df, movements_df

if __name__ == "__main__":
    from generator.generate.countries import generate_countries
    from generator.generate.cities import generate_cities
    from generator.generate.categories import generate_categories
    from generator.generate.suppliers import generate_suppliers
    from generator.generate.products import generate_products
    from generator.generate.warehouses import generate_warehouses
    co = generate_countries()
    ci = generate_cities(co)
    ca = generate_categories()
    su = generate_suppliers(ci, ca)
    pr = generate_products(ca, su)
    wa = generate_warehouses(ci)
    generate_inventory(pr, wa)
