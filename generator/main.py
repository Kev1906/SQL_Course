import random
import numpy as np
import psycopg
from generator.config import SEED
from generator.generate.countries import generate_countries
from generator.generate.cities import generate_cities
from generator.generate.categories import generate_categories
from generator.generate.suppliers import generate_suppliers
from generator.generate.products import generate_products
from generator.generate.employees import generate_employees_and_departments
from generator.generate.warehouses import generate_warehouses
from generator.generate.customers import generate_customers
from generator.generate.inventory import generate_inventory
from generator.generate.promotions import generate_promotions_and_coupons
from generator.generate.orders import generate_orders_and_items
from generator.generate.payments import generate_payments
from generator.generate.reviews import generate_reviews
from generator.insert import import_all_csvs

def main():
    print("==================================================")
    print("DataMartX Synthetic Data Generator Orchestrator")
    print(f"Initializing with Seed: {SEED}")
    print("==================================================")
    
    # Set global seeds
    random.seed(SEED)
    np.random.seed(SEED)
    
    # 1. Countries
    countries_df = generate_countries()
    
    # 2. Cities
    cities_df = generate_cities(countries_df)
    
    # 3. Categories
    categories_df = generate_categories()
    
    # 4. Suppliers
    suppliers_df = generate_suppliers(cities_df, categories_df)
    
    # 5. Products
    products_df = generate_products(categories_df, suppliers_df)
    
    # 6. Departments & Employees
    departments_df, employees_df = generate_employees_and_departments()
    
    # 7. Warehouses
    warehouses_df = generate_warehouses(cities_df)
    
    # 8. Customers
    customers_df = generate_customers(cities_df)
    
    # 9. Stocks & Stock Movements (Inventory)
    stocks_df, movements_df = generate_inventory(products_df, warehouses_df)
    
    # 10. Promotions & Coupons
    promotions_df, coupons_df = generate_promotions_and_coupons()
    
    # 11. Orders, Order Items, Shippers, Invoices, Shipments, Returns
    orders_df, order_items_df, shippers_df, invoices_df, shipments_df, returns_df = \
        generate_orders_and_items(customers_df, products_df, employees_df, promotions_df, coupons_df)
        
    # 12. Payments
    payments_df = generate_payments(orders_df)
    
    # 13. Reviews
    reviews_df = generate_reviews(orders_df, order_items_df, customers_df)
    
    print("\n--------------------------------------------------")
    print("All CSV datasets successfully generated!")
    print("--------------------------------------------------\n")
    
    # Trigger database loading via COPY
    try:
        import_all_csvs()
    except psycopg.OperationalError as e:
        print("[WARNING] Could not connect to the PostgreSQL database.")
        print("Detail:", e)
        print("\nAll CSV files are saved in the 'generator/temp_csv/' directory.")
        print("To load them into PostgreSQL later, please:")
        print("  1. Start Docker Desktop and run: docker compose up -d")
        print("  2. Run the database schema scripts in database/schema/ (01 to 05)")
        print("  3. Run the importer: python generator/insert.py")
    except Exception as ex:
        print(f"[ERROR] An unexpected error occurred during database load: {ex}")

if __name__ == "__main__":
    main()
