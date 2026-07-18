import random
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from generator.generate.utils import save_to_csv
from generator.config import ORDERS_COUNT, SEED
from generator.faker_utils import generate_tracking_number, generate_invoice_number
from tqdm import tqdm

def generate_orders_and_items(customers_df, products_df, employees_df, promotions_df, coupons_df):
    random.seed(SEED)
    np.random.seed(SEED)
    
    customers = customers_df.to_dict(orient="records")
    products = products_df.to_dict(orient="records")
    employees = employees_df["id"].tolist()
    promotions = promotions_df.to_dict(orient="records")
    coupons = coupons_df.to_dict(orient="records")
    
    # Organize products
    prod_by_id = {p["id"]: p for p in products}
    # Sports categories: 4 (Sports & Outdoors), 21 (Fitness & Gym), 22 (Outdoor Recreation), 23 (Cycling & Bikes)
    sports_products = [p for p in products if p["category_id"] in [4, 21, 22, 23]]
    all_products = products
    
    # 1. Define order item counts: exactly 320,000 items across 80,000 orders
    # 20k orders with 2 items, 20k with 3 items, 20k with 5 items, 20k with 6 items
    # Average items per order = (40k + 60k + 100k + 120k) / 80k = 320k / 80k = 4
    item_counts = [2]*20000 + [3]*20000 + [5]*20000 + [6]*20000
    random.shuffle(item_counts)
    
    # Group customers by segment
    cust_by_segment = {"Premium": [], "Sports Enthusiast": [], "Occasional": [], "Standard": []}
    for c in customers:
        cust_by_segment[c["segment"]].append(c)
            
    orders = []
    order_items = []
    
    # Staggered order date generator with seasonal weighting
    # Date range: 2023-01-01 to 2026-06-30 (1276 days)
    start_date = datetime(2023, 1, 1)
    
    days_pool = []
    for day_idx in range(1276):
        date_val = start_date + timedelta(days=day_idx)
        month = date_val.month
        day = date_val.day
        
        weight = 1.0
        # Seasonality
        if month == 11 and day >= 20: # Black Friday peak
            weight = 4.0
        elif month == 12 and day <= 24: # Christmas peak
            weight = 3.5
        elif month in [6, 7]: # Summer sales
            weight = 1.8
        elif month == 2: # Winter lull
            weight = 0.7
            
        days_pool.append((date_val, weight))
        
    dates_only, weights_only = zip(*days_pool)
    weights_only = np.array(weights_only)
    weights_only = weights_only / weights_only.sum()
    
    # Distribute 80,000 orders to customers
    order_assignments = []
    
    # Occasional: exactly 1 order per customer.
    occ_custs = cust_by_segment["Occasional"]
    for c in occ_custs[:8000]:
        order_assignments.append((c, 1))
    while len(order_assignments) < 8000:
        order_assignments.append((random.choice(occ_custs), 1))
        
    # Premium: ~25,000 orders distributed among ~1000 customers
    prem_custs = cust_by_segment["Premium"]
    prem_orders = 25000
    prem_counts = np.random.multinomial(prem_orders, [1.0/len(prem_custs)] * len(prem_custs))
    for c, count in zip(prem_custs, prem_counts):
        order_assignments.append((c, count))
        
    # Sports Enthusiast: ~20,000 orders distributed among ~3000 customers
    sports_custs = cust_by_segment["Sports Enthusiast"]
    sports_orders = 20000
    sports_counts = np.random.multinomial(sports_orders, [1.0/len(sports_custs)] * len(sports_custs))
    for c, count in zip(sports_custs, sports_counts):
        order_assignments.append((c, count))
        
    # Standard: ~27,000 orders distributed among ~8000 customers
    std_custs = cust_by_segment["Standard"]
    std_orders = 27000
    std_counts = np.random.multinomial(std_orders, [1.0/len(std_custs)] * len(std_custs))
    for c, count in zip(std_custs, std_counts):
        order_assignments.append((c, count))
        
    flattened_assignments = []
    for c, count in order_assignments:
        flattened_assignments.extend([c] * count)
        
    if len(flattened_assignments) > ORDERS_COUNT:
        flattened_assignments = flattened_assignments[:ORDERS_COUNT]
    elif len(flattened_assignments) < ORDERS_COUNT:
        extra_needed = ORDERS_COUNT - len(flattened_assignments)
        flattened_assignments.extend(random.choices(customers, k=extra_needed))
        
    random.shuffle(flattened_assignments)
    
    order_item_id = 1
    
    # Convert promotions to active periods
    promo_periods = []
    for p in promotions:
        s_dt = datetime.strptime(p["start_date"], "%Y-%m-%d")
        e_dt = datetime.strptime(p["end_date"], "%Y-%m-%d")
        promo_periods.append((s_dt, e_dt, p["id"], p["discount_percentage"]))
        
    print("Generating 80,000 orders and 320,000 order items...")
    for order_idx in tqdm(range(ORDERS_COUNT)):
        customer = flattened_assignments[order_idx]
        cust_id = customer["id"]
        segment = customer["segment"]
        
        # Generate Order Date
        order_datetime = np.random.choice(dates_only, p=weights_only)
        order_datetime = order_datetime + timedelta(
            hours=random.randint(8, 22),
            minutes=random.randint(0, 59),
            seconds=random.randint(0, 59)
        )
        order_date_str = order_datetime.strftime("%Y-%m-%d %H:%M:%S")
        
        num_items = item_counts[order_idx]
        
        prod_pool = sports_products if segment == "Sports Enthusiast" else all_products
        order_prods = random.sample(prod_pool, num_items)
        
        promo_id = None
        promo_pct = 0.00
        for s_dt, e_dt, p_id, p_pct in promo_periods:
            if s_dt <= order_datetime <= e_dt:
                promo_id = p_id
                promo_pct = float(p_pct)
                break
                
        emp_id = random.choice(employees) if random.random() > 0.7 else None
        
        total_amount = 0.00
        discount_amount = 0.00
        
        items_temp = []
        
        for p in order_prods:
            qty = random.randint(1, 3)
            if segment == "Premium" and random.random() > 0.5:
                qty = random.randint(2, 5)
                
            unit_price = float(p["price"])
            item_gross = unit_price * qty
            
            item_discount = round(item_gross * (promo_pct / 100.00), 2)
            item_subtotal = round(item_gross - item_discount, 2)
            
            total_amount += item_gross
            discount_amount += item_discount
            
            items_temp.append({
                "id": order_item_id,
                "order_id": order_idx + 1,
                "product_id": p["id"],
                "quantity": qty,
                "unit_price": unit_price,
                "discount_amount": item_discount,
                "subtotal": item_subtotal
            })
            order_item_id += 1
            
        coupon_id = None
        if segment == "Premium" and random.random() > 0.4:
            eligible_coupons = [c for c in coupons if c["is_active"] and float(c["min_purchase_amount"]) <= total_amount]
            if eligible_coupons:
                chosen_coupon = random.choice(eligible_coupons)
                coupon_id = chosen_coupon["id"]
                discount_amount += float(chosen_coupon["discount_amount"])
                
        discount_amount = round(discount_amount, 2)
        total_amount = round(total_amount, 2)
        net_amount = round(total_amount - discount_amount, 2)
        
        if net_amount < 0.00:
            net_amount = 0.00
            discount_amount = total_amount
            
        if segment in ["Premium", "Sports Enthusiast"]:
            status = random.choices(["Delivered", "Shipped", "Processing"], weights=[0.85, 0.12, 0.03])[0]
        elif segment == "Occasional":
            status = "Delivered"
        else: # Standard
            status = random.choices(["Delivered", "Shipped", "Processing", "Cancelled", "Returned"], weights=[0.80, 0.10, 0.04, 0.02, 0.04])[0]
            
        orders.append({
            "id": order_idx + 1,
            "customer_id": cust_id,
            "employee_id": emp_id,
            "promotion_id": promo_id,
            "coupon_id": coupon_id,
            "order_date": order_date_str,
            "status": status,
            "total_amount": total_amount,
            "discount_amount": discount_amount,
            "net_amount": net_amount
        })
        
        order_items.extend(items_temp)
        
    assert len(order_items) == 320000, f"Expected 320,000 order items, got {len(order_items)}"
    
    orders_df = pd.DataFrame(orders)
    orders_df["employee_id"] = orders_df["employee_id"].astype("Int64")
    orders_df["promotion_id"] = orders_df["promotion_id"].astype("Int64")
    orders_df["coupon_id"] = orders_df["coupon_id"].astype("Int64")
    order_items_df = pd.DataFrame(order_items)
    
    save_to_csv(orders_df, "orders.csv")
    save_to_csv(order_items_df, "order_items.csv")
    
    # -------------------------------------------------------------------------
    # GENERATE DEPENDENT SALES/LOGISTICS DATASETS
    # -------------------------------------------------------------------------
    
    # 1. Shippers (5 carriers)
    shippers_data = [
        {"id": 1, "name": "DHL Express", "phone": "+1-800-225-5345", "email": "support@dhl.com"},
        {"id": 2, "name": "FedEx", "phone": "+1-800-463-3339", "email": "support@fedex.com"},
        {"id": 3, "name": "UPS", "phone": "+1-800-742-5877", "email": "support@ups.com"},
        {"id": 4, "name": "USPS", "phone": "+1-800-275-8777", "email": "support@usps.com"},
        {"id": 5, "name": "Amazon Logistics", "phone": "+1-877-252-2701", "email": "shipping@amazon.com"}
    ]
    shippers_df = pd.DataFrame(shippers_data)
    save_to_csv(shippers_df, "shippers.csv")
    
    # 2. Invoices (80,000 invoices matching the 80,000 orders)
    invoices = []
    print("Generating invoices...")
    for o in orders:
        o_id = o["id"]
        net = o["net_amount"]
        dt = datetime.strptime(o["order_date"], "%Y-%m-%d %H:%M:%S")
        issue_date_str = dt.strftime("%Y-%m-%d")
        due_date_str = (dt + timedelta(days=30)).strftime("%Y-%m-%d")
        
        tax = round(net * 0.19, 2)
        
        status = "Paid"
        if o["status"] == "Cancelled":
            status = "Cancelled"
        elif o["status"] == "Pending":
            status = "Unpaid"
        elif o["status"] == "Processing" and random.random() > 0.8:
            status = "Unpaid"
            
        invoices.append({
            "id": o_id,
            "order_id": o_id,
            "invoice_number": generate_invoice_number(o_id, dt.year),
            "issue_date": issue_date_str,
            "due_date": due_date_str,
            "tax_amount": tax,
            "total_amount": net,
            "status": status
        })
    invoices_df = pd.DataFrame(invoices)
    save_to_csv(invoices_df, "invoices.csv")
    
    # 3. Shipments (for Shipped, Delivered, and Returned orders)
    shipments = []
    shipment_id = 1
    
    shippable_orders = [o for o in orders if o["status"] in ["Shipped", "Delivered", "Returned"]]
    print("Generating shipments...")
    for o in shippable_orders:
        o_id = o["id"]
        o_dt = datetime.strptime(o["order_date"], "%Y-%m-%d %H:%M:%S")
        
        ship_date = o_dt + timedelta(days=random.randint(1, 2))
        ship_date_str = ship_date.strftime("%Y-%m-%d %H:%M:%S")
        
        est_delivery_str = (ship_date + timedelta(days=random.randint(3, 5))).strftime("%Y-%m-%d")
        
        if o["status"] in ["Delivered", "Returned"]:
            status = "Delivered"
            del_date = ship_date + timedelta(days=random.randint(2, 4), hours=random.randint(-4, 4))
            del_date_str = del_date.strftime("%Y-%m-%d %H:%M:%S")
        else:
            status = "In Transit"
            del_date_str = None
            
        shipments.append({
            "id": shipment_id,
            "order_id": o_id,
            "shipper_id": random.randint(1, 5),
            "tracking_number": generate_tracking_number(shipment_id),
            "status": status,
            "shipment_date": ship_date_str,
            "estimated_delivery": est_delivery_str,
            "delivery_date": del_date_str
        })
        shipment_id += 1
        
    shipments_df = pd.DataFrame(shipments)
    save_to_csv(shipments_df, "shipments.csv")
    
    # 4. Returns (for Returned orders)
    returns = []
    return_id = 1
    
    returned_orders = [o for o in orders if o["status"] == "Returned"]
    returned_order_ids = {o["id"]: o for o in returned_orders}
    
    # Map shipment delivery date for return date sequencing
    del_dates_by_order = {s["order_id"]: datetime.strptime(s["delivery_date"], "%Y-%m-%d %H:%M:%S") 
                          for s in shipments if s["order_id"] in returned_order_ids and s["delivery_date"] is not None}
    
    # Group order items by returned orders
    returned_items = [item for item in order_items if item["order_id"] in returned_order_ids]
    
    print("Generating returns...")
    for item in returned_items:
        # We can return all or some items of the order. Let's return with 75% probability to simulate partial returns
        if random.random() > 0.75:
            continue
            
        o_id = item["order_id"]
        
        # Resolve return date (delivery date + 1 to 5 days)
        del_date = del_dates_by_order.get(o_id)
        if del_date is None:
            # Fallback if delivery date wasn't recorded
            del_date = datetime.strptime(returned_order_ids[o_id]["order_date"], "%Y-%m-%d %H:%M:%S") + timedelta(days=4)
            
        ret_date = del_date + timedelta(days=random.randint(1, 5), hours=random.randint(-4, 4))
        ret_date_str = ret_date.strftime("%Y-%m-%d %H:%M:%S")
        
        reason = random.choice(['Defective', 'Wrong Item', 'Size Mismatch', 'Not as Described', 'Buyer Remorse'])
        status = random.choices(['Completed', 'Approved', 'Inspected'], weights=[0.80, 0.15, 0.05])[0]
        
        # Return processor (support agent from 200 to 300)
        emp_id = random.choice(employees[199:]) if len(employees) >= 200 else random.choice(employees)
        
        returns.append({
            "id": return_id,
            "order_item_id": item["id"],
            "employee_id": emp_id,
            "reason": reason,
            "status": status,
            "refund_amount": item["subtotal"],
            "return_date": ret_date_str
        })
        return_id += 1
        
    returns_df = pd.DataFrame(returns)
    returns_df["employee_id"] = returns_df["employee_id"].astype("Int64")
    save_to_csv(returns_df, "returns.csv")
    
    return orders_df, order_items_df, shippers_df, invoices_df, shipments_df, returns_df

if __name__ == "__main__":
    pass
