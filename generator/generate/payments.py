import random
import pandas as pd
from datetime import datetime, timedelta
from generator.generate.utils import save_to_csv
from generator.config import PAYMENTS_COUNT

def generate_payments(orders_df):
    orders = orders_df.to_dict(orient="records")
    payments = []
    
    payment_methods = ['Credit Card', 'PayPal', 'Bank Transfer', 'Cryptocurrency', 'Gift Card']
    method_weights = [0.55, 0.25, 0.10, 0.05, 0.05]
    
    payment_id = 1
    
    for o in orders:
        order_id = o["id"]
        order_date_str = o["order_date"]
        order_status = o["status"]
        net_amount = o["net_amount"]
        
        # Payment Date: Order Date + 1 to 5 minutes
        order_date = datetime.strptime(order_date_str, "%Y-%m-%d %H:%M:%S")
        pay_date = order_date + timedelta(seconds=random.randint(30, 300))
        pay_date_str = pay_date.strftime("%Y-%m-%d %H:%M:%S")
        
        method = random.choices(payment_methods, weights=method_weights)[0]
        
        # Status alignment
        if order_status == "Cancelled":
            # 50% Refunded, 50% Failed
            pay_status = "Refunded" if random.random() > 0.5 else "Failed"
        elif order_status == "Returned":
            pay_status = "Refunded"
        elif order_status == "Pending":
            pay_status = "Pending"
        else:
            pay_status = "Completed"
            
        payments.append({
            "id": payment_id,
            "order_id": order_id,
            "payment_date": pay_date_str,
            "payment_method": method,
            "amount": net_amount,
            "status": pay_status
        })
        
        payment_id += 1
        
    assert len(payments) == PAYMENTS_COUNT, f"Expected {PAYMENTS_COUNT} payments, got {len(payments)}"
    
    df = pd.DataFrame(payments)
    save_to_csv(df, "payments.csv")
    return df

if __name__ == "__main__":
    pass
