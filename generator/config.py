import os
from pathlib import Path
from dotenv import load_dotenv

# Load environmental variables from root path
BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

# Database configuration
DB_HOST = os.getenv("POSTGRES_HOST", "localhost")
DB_PORT = int(os.getenv("POSTGRES_PORT", 5432))
DB_NAME = os.getenv("POSTGRES_DB", "datamartx")
DB_USER = os.getenv("POSTGRES_USER", "student")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "student")

# Data volume definitions
COUNTRIES_COUNT = 100
CITIES_COUNT = 800
SUPPLIERS_COUNT = 200
CATEGORIES_COUNT = 30
PRODUCTS_COUNT = 5000
EMPLOYEES_COUNT = 300
WAREHOUSES_COUNT = 8
CUSTOMERS_COUNT = 20000
ORDERS_COUNT = 80000
PAYMENTS_COUNT = 80000
ORDER_ITEMS_AVG_PER_ORDER = 4  # Gives exactly 320,000 order items
STOCKS_COUNT = 40000  # 8 warehouses * 5000 products = 40,000

# Random Seed
SEED = 42

# CSV output directory
CSV_DIR = BASE_DIR / "generator" / "temp_csv"
CSV_DIR.mkdir(parents=True, exist_ok=True)
