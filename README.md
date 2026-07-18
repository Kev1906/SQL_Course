# SQL Master Course - DataMartX Enterprise Marketplace

Welcome to the **SQL Master Course** repository! This is a production-grade, highly complex relational database system designed around a fictitious international marketplace called **DataMartX** (similar to Amazon, Uber, or Microsoft Store). 

It is specifically built as a training ground for software engineers, database administrators, and data engineers to master SQL from intermediate concepts to advanced production techniques.

---

## 🚀 Key Topics Covered
The schema, volume, and advanced objects in this database are designed to teach:
* **Advanced Joins & Set Operations**
* **Window Functions & Reporting** (dense_rank, lag/lead, frame clauses)
* **CTEs & Recursive Queries** (organizational charts, nested categories)
* **Performance Tuning & Query Planner Analysis** (EXPLAIN ANALYZE, custom indexing)
* **Stored Procedures & Triggers** (transactional checkouts, automatic audits, archiving)
* **Modern Database Engineering** (dbt, Airflow, CDC, Star Schema, JSONB querying)

---

## 🛠 Technology Stack
* **Database**: PostgreSQL 17
* **Virtualization**: Docker Compose
* **Data Generation**: Python 3.12, Faker, pandas, numpy, tqdm
* **Database Driver**: psycopg3 (utilizing binary stream `COPY` operations)

---

## 📁 Repository Structure
```text
sql-master-course/
├── docker-compose.yml       # Docker definition for PostgreSQL 17
├── .env.example             # Configuration variables template
├── README.md                # Main repository documentation (this file)
├── .gitignore               # Ignored local environments and generated CSVs
│
├── database/
│   └── schema/
│       ├── 01_schema.sql    # Creates 8 schemas and 23 tables with full constraints
│       ├── 02_indexes.sql   # Creates B-Tree, Composite, Partial, and GIN indexes
│       ├── 03_views.sql     # Standard analytical views and Materialized views
│       ├── 04_functions.sql # Transactional stored procedures and analytics functions
│       └── 05_triggers.sql  # Triggers for timestamps, change logs, and soft deletes
│
├── migrations/              # Directory for future schema migrations
│   └── README.md
│
├── docs/
│   ├── data_dictionary.md   # Complete column and constraint documentation
│   └── erd.png              # Entity Relationship Diagram (Visual Schema)
│
├── generator/
│   ├── requirements.txt     # Python generator dependencies
│   ├── config.py            # Settings, constants, and volume definitions
│   ├── faker_utils.py       # Custom providers for SKU, phone formats, etc.
│   ├── insert.py            # Stream loading script utilizing psycopg3 COPY
│   ├── main.py              # Main orchestrator running all generator components
│   └── generate/
│       ├── utils.py         # CSV saving helpers
│       ├── countries.py     # Generates 100 unique countries
│       ├── cities.py        # Generates 800 cities distributed across countries
│       ├── customers.py     # Generates 20,000 customers with segment profiles
│       ├── categories.py    # Generates 30 hierarchical product categories
│       ├── suppliers.py     # Generates 200 suppliers with category focuses
│       ├── products.py      # Generates 5,000 products with JSONB attributes
│       ├── employees.py     # Generates 8 departments and 300 employees
│       ├── warehouses.py    # Generates 8 regional warehouse hubs
│       ├── inventory.py     # Generates 40,000 stocks and inbound logs
│       ├── promotions.py    # Generates campaigns and 50 unique coupons
│       ├── orders.py        # Generates 80,000 orders and 320,000 items
│       ├── payments.py      # Generates 80,000 payments
│       └── reviews.py       # Generates 32k product reviews based on orders
│
├── exercises/
│   └── day001.sql           # Day 1 intermediate challenges
└── solutions/
    └── day001.sql           # Day 1 detailed query solutions
```

---

## ⚡ Setup & Installation

### 1. Start the PostgreSQL Database
Make sure you have **Docker Desktop** running on your machine, then execute:
```bash
docker compose up -d
```
This boots up a PostgreSQL 17 server listening on `localhost:5432` with database `datamartx`, username `student`, and password `student`.

### 2. Load the Schema
Run the SQL scripts in the `database/schema/` directory in sequential order:
1. `01_schema.sql` (Schemas, types, tables)
2. `02_indexes.sql` (Performance indexes)
3. `03_views.sql` (Views and Materialized Views)
4. `04_functions.sql` (Stored procedures and functions)
5. `05_triggers.sql` (Audit logging, timestamps)

*(Alternatively, you can run them inside the container via `psql` or use your database GUI, like DBeaver).*

### 3. Generate and Ingest Synthetic Data
To generate and load the 500,000+ data rows, set up your python environment:

```bash
# 1. Create a virtual environment
python -m venv venv

# 2. Activate the virtual environment
# On Windows:
.\venv\Scripts\activate
# On Linux/macOS:
source venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Generate and load all data (takes ~15 seconds)
python -m generator.main
```

---

## 📈 Data Volumes Generated
The dataset is generated with high coherence (customer purchasing profiles, supplier-category focus, stock replenishments, and delivery states) matching exactly:
* **100** Countries
* **800** Cities
* **200** Suppliers
* **30** Product Categories (nested hierarchy)
* **5,000** Products (equipped with JSONB specs)
* **300** Employees (arranged in reporting trees)
* **8** Warehouses
* **20,000** Customers (categorized by shopping segments)
* **40,000** Inventory Records (stocks)
* **40,000** Inbound Inventory Movements (initial stocks)
* **80,000** Orders (following calendar seasonality)
* **320,000** Order Items (average 4 items per order)
* **80,000** Invoices
* **77,028** Shipments (covering transit tracking)
* **3,105** Returns
* **80,000** Payments
* **32,479** Product Reviews (coherent customer purchases)