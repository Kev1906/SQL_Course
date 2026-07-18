import psycopg
from generator.config import (
    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, CSV_DIR, BASE_DIR
)

def import_all_csvs():
    # Insertion configuration
    tables_to_load = [
        ("core.countries", "countries.csv", ["id", "code", "name", "region"]),
        ("core.cities", "cities.csv", ["id", "country_id", "name", "state_province"]),
        ("core.customers", "customers.csv", ["id", "city_id", "first_name", "last_name", "email", "phone", "gender", "segment", "birth_date", "is_active"]),
        ("core.suppliers", "suppliers.csv", ["id", "city_id", "name", "contact_name", "email", "phone", "category_focus"]),
        ("hr.departments", "departments.csv", ["id", "name", "budget", "manager_id"]),
        ("hr.employees", "employees.csv", ["id", "department_id", "manager_id", "first_name", "last_name", "email", "job_title", "salary", "hire_date", "is_active"]),
        ("marketing.categories", "categories.csv", ["id", "parent_id", "name", "description"]),
        ("marketing.promotions", "promotions.csv", ["id", "name", "discount_percentage", "start_date", "end_date"]),
        ("marketing.coupons", "coupons.csv", ["id", "promotion_id", "code", "discount_amount", "min_purchase_amount", "is_active"]),
        ("inventory.products", "products.csv", ["id", "category_id", "supplier_id", "name", "sku", "price", "cost", "description", "attributes", "is_active"]),
        ("marketing.reviews", "reviews.csv", ["id", "customer_id", "product_id", "rating", "comment", "created_at"]),
        ("inventory.warehouses", "warehouses.csv", ["id", "city_id", "name", "address", "capacity"]),
        ("inventory.stocks", "stocks.csv", ["id", "warehouse_id", "product_id", "quantity", "reorder_level"]),
        ("inventory.movements", "movements.csv", ["id", "stock_id", "movement_type", "quantity", "reference_id", "movement_date"]),
        ("sales.orders", "orders.csv", ["id", "customer_id", "employee_id", "promotion_id", "coupon_id", "order_date", "status", "total_amount", "discount_amount", "net_amount"]),
        ("sales.order_items", "order_items.csv", ["id", "order_id", "product_id", "quantity", "unit_price", "discount_amount", "subtotal"]),
        ("sales.payments", "payments.csv", ["id", "order_id", "payment_date", "payment_method", "amount", "status"]),
        ("sales.invoices", "invoices.csv", ["id", "order_id", "invoice_number", "issue_date", "due_date", "tax_amount", "total_amount", "status"]),
        ("logistics.shippers", "shippers.csv", ["id", "name", "phone", "email"]),
        ("logistics.shipments", "shipments.csv", ["id", "order_id", "shipper_id", "tracking_number", "status", "shipment_date", "estimated_delivery", "delivery_date"]),
        ("logistics.returns", "returns.csv", ["id", "order_item_id", "employee_id", "reason", "status", "refund_amount", "return_date"])
    ]
    
    conn_str = f"host={DB_HOST} port={DB_PORT} dbname={DB_NAME} user={DB_USER} password={DB_PASSWORD}"
    
    print("\nConnecting to PostgreSQL database...")
    with psycopg.connect(conn_str) as conn:
        with conn.cursor() as cur:
            # 0. Apply schema files in order (skip if already applied)
            print("Checking if schemas are already applied...")
            cur.execute("SELECT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'countries' AND schemaname = 'core')")
            tables_exist = cur.fetchone()[0]
            if not tables_exist:
                print("Applying database schemas (01 to 05)...")
                schema_files = [
                    "database/schema/01_schema.sql",
                    "database/schema/02_indexes.sql",
                    "database/schema/03_views.sql",
                    "database/schema/04_functions.sql",
                    "database/schema/05_triggers.sql"
                ]
                for sf in schema_files:
                    path = BASE_DIR / sf
                    print(f"  -> Executing {sf}...")
                    with open(path, "r", encoding="utf-8") as f:
                        sql = f.read()
                        cur.execute(sql)
            else:
                print("Schemas already exist, skipping creation.")
                    
            # 1. Disable triggers and foreign keys temporarily for current session
            print("Configuring session replication role to replica...")
            cur.execute("SET session_replication_role = 'replica';")
            
            # 2. Truncate all tables to prevent primary key collisions (clean run)
            print("Truncating tables for fresh import...")
            all_tables = [t[0] for t in tables_to_load] + ["audit.logs", "audit.deleted_rows"]
            cur.execute(f"TRUNCATE TABLE {', '.join(all_tables)} RESTART IDENTITY CASCADE;")
            
            # 3. Import each CSV using high-speed COPY
            print("\nStreaming datasets into database tables:")
            for table, csv_file, columns in tables_to_load:
                file_path = CSV_DIR / csv_file
                if not file_path.exists():
                    print(f"  [ERROR] File not found: {file_path}")
                    continue
                
                cols_str = ", ".join(columns)
                copy_query = f"COPY {table} ({cols_str}) FROM STDIN WITH (FORMAT CSV, HEADER)"
                
                print(f"  -> COPYing {csv_file} to {table}...")
                with open(file_path, "r", encoding="utf-8") as f:
                    with cur.copy(copy_query) as copy:
                        while chunk := f.read(1024 * 1024):
                            copy.write(chunk)
                            
            # 4. Restore standard session replication settings
            print("\nRestoring session replication role to origin...")
            cur.execute("SET session_replication_role = 'origin';")
            
            # 5. Refresh Materialized Views
            print("Refreshing analytical materialized views...")
            cur.execute("REFRESH MATERIALIZED VIEW analytics.mv_stock_status;")
            cur.execute("REFRESH MATERIALIZED VIEW analytics.mv_slow_moving_inventory;")
            
            # Commit the transaction
            conn.commit()
            print("\nData loading completed successfully!")

if __name__ == "__main__":
    import_all_csvs()
