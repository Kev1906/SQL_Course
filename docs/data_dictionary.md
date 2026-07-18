# DataMartX Database Data Dictionary

This document serves as the official data dictionary for the **DataMartX** e-commerce marketplace database, designed to teach intermediate-to-expert level SQL, database engineering, and data warehousing.

The database is divided into **8 schemas**:
1. `core`: Geo-location, supplier, and customer directory data.
2. `hr`: Corporate organizational structure, salaries, and personnel.
3. `marketing`: Catalog categories, promotions, coupons, and product reviews.
4. `inventory`: Product details, warehouse listings, stock levels, and supply ledger.
5. `sales`: Orders, basket line items, payment processing, and billing.
6. `logistics`: Shippers, tracking delivery states, and inventory returns.
7. `analytics`: General ledger aggregates, cohort views, and materialized views.
8. `audit`: Audit ledgers tracking modifications and deleted historical rows.

---

## 1. Schema: core

### Table: `core.countries`
Holds the geopolitical international country directory.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY`, `GENERATED ALWAYS AS IDENTITY` | Unique sequential identifier. |
| `uuid` | `UUID` | `UNIQUE`, `DEFAULT gen_random_uuid()` | Universally unique external reference identifier. |
| `code` | `CHAR(2)` | `UNIQUE`, `NOT NULL`, `CHECK (length = 2)` | ISO-2 letter country code (e.g., 'US', 'ES'). |
| `name` | `VARCHAR(100)` | `UNIQUE`, `NOT NULL` | Country name (e.g., 'United States', 'Spain'). |
| `region` | `VARCHAR(50)` | `NOT NULL`, `CHECK (in Region List)` | Geographic continent group. |
| `created_at` | `TIMESTAMPTZ` | `DEFAULT CURRENT_TIMESTAMP` | Auditing creation timestamp. |
| `updated_at` | `TIMESTAMPTZ` | `DEFAULT CURRENT_TIMESTAMP` | Auditing update timestamp. |

### Table: `core.cities`
Contains cities mapped to countries.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY`, `IDENTITY` | Unique identifier. |
| `uuid` | `UUID` | `UNIQUE`, `DEFAULT` | External identifier. |
| `country_id` | `BIGINT` | `FOREIGN KEY -> core.countries(id)` | Associated country. |
| `name` | `VARCHAR(100)` | `NOT NULL` | City name (e.g., 'Madrid', 'New York'). |
| `state_province` | `VARCHAR(100)`| `NULL` | State, province, or region. |
| `created_at` | `TIMESTAMPTZ` | `DEFAULT` | Creation timestamp. |
| `updated_at` | `TIMESTAMPTZ` | `DEFAULT` | Update timestamp. |

### Table: `core.customers`
Contains customer identity profiles.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY`, `IDENTITY` | Unique identifier. |
| `uuid` | `UUID` | `UNIQUE`, `DEFAULT` | External identifier. |
| `city_id` | `BIGINT` | `FOREIGN KEY -> core.cities(id)` | Residential city. |
| `first_name` | `VARCHAR(100)` | `NOT NULL` | Customer first name. |
| `last_name` | `VARCHAR(100)` | `NOT NULL` | Customer last name. |
| `email` | `core.email_type` | `UNIQUE`, `NOT NULL` | Valid email address. |
| `phone` | `core.phone_type` | `NULL` | Formatted phone number. |
| `gender` | `core.gender_enum` | `NOT NULL` | Demographics identifier. |
| `segment` | `core.segment_enum` | `NOT NULL`, `DEFAULT 'Standard'` | Premium, Occasional, Sports, or Standard. |
| `birth_date` | `DATE` | `NOT NULL`, `CHECK (age >= 18)` | Date of birth. |
| `is_active` | `BOOLEAN` | `DEFAULT TRUE` | Customer status flag. |
| `created_at` | `TIMESTAMPTZ` | `DEFAULT` | Creation timestamp. |
| `updated_at` | `TIMESTAMPTZ` | `DEFAULT` | Update timestamp. |

### Table: `core.suppliers`
Merchant directory supplying catalogue items.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Unique identifier. |
| `city_id` | `BIGINT` | `FOREIGN KEY -> core.cities(id)` | Corporate location. |
| `name` | `VARCHAR(150)` | `UNIQUE`, `NOT NULL` | Legal supplier business name. |
| `contact_name` | `VARCHAR(150)` | `NOT NULL` | Primary account manager. |
| `email` | `core.email_type` | `NOT NULL` | Contact email. |
| `phone` | `core.phone_type` | `NOT NULL` | Phone number. |
| `category_focus` | `VARCHAR(50)` | `NOT NULL` | Industry catalog category. |

---

## 2. Schema: hr

### Table: `hr.departments`
Corporate cost departments.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Unique identifier. |
| `name` | `VARCHAR(100)` | `UNIQUE`, `NOT NULL` | Department name. |
| `budget` | `NUMERIC(15,2)`| `CHECK (budget > 0)` | Operational budget limits. |
| `manager_id` | `BIGINT` | `FOREIGN KEY -> hr.employees(id)` | Director leading the department. |

### Table: `hr.employees`
Marketplace corporate workforce.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Employee ID. |
| `department_id`| `BIGINT` | `FOREIGN KEY -> hr.departments(id)` | Corporate department allocation. |
| `manager_id` | `BIGINT` | `FOREIGN KEY -> hr.employees(id)` | Direct supervisor. |
| `first_name` | `VARCHAR(100)` | `NOT NULL` | First name. |
| `last_name` | `VARCHAR(100)` | `NOT NULL` | Last name. |
| `email` | `core.email_type` | `UNIQUE`, `NOT NULL` | Corporate email. |
| `job_title` | `VARCHAR(100)` | `NOT NULL` | Role description. |
| `salary` | `NUMERIC(12,2)`| `CHECK (salary > 0)` | Annual compensation. |
| `hire_date` | `DATE` | `CHECK (hire_date <= CURRENT_DATE)` | Onboarding date. |
| `is_active` | `BOOLEAN` | `DEFAULT TRUE` | Active employment flag. |

---

## 3. Schema: marketing

### Table: `marketing.categories`
Product catalog hierarchy trees.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Category ID. |
| `parent_id` | `BIGINT` | `FOREIGN KEY -> marketing.categories(id)` | Parent category node. |
| `name` | `VARCHAR(100)` | `UNIQUE`, `NOT NULL` | Display name. |
| `description` | `TEXT` | `NULL` | Detailed description. |

### Table: `marketing.promotions`
Discount campaigns.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Campaign ID. |
| `name` | `VARCHAR(150)` | `NOT NULL` | Promotion name. |
| `discount_percentage`| `NUMERIC(5,2)` | `CHECK (0 < discount_pct <= 100)` | Campaign percentage discount. |
| `start_date` | `DATE` | `NOT NULL` | Active start range. |
| `end_date` | `DATE` | `CHECK (end_date >= start_date)` | Expiration date boundary. |

### Table: `marketing.coupons`
Individual promo coupon checkout tokens.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Coupon ID. |
| `promotion_id` | `BIGINT` | `FOREIGN KEY -> marketing.promotions(id)` | Parent campaign (optional). |
| `code` | `VARCHAR(50)` | `UNIQUE`, `NOT NULL`, `CHECK (length >= 3)` | Alpha-numeric coupon code. |
| `discount_amount`| `sales.price_type` | `CHECK (discount_amount > 0)` | Flat currency discount value. |
| `min_purchase_amount`| `sales.price_type`| `DEFAULT 0.00`, `CHECK (min >= 0)` | Basket requirement. |
| `is_active` | `BOOLEAN` | `DEFAULT TRUE` | Status toggle. |

### Table: `marketing.reviews`
Product reviews submitted by customers.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Review ID. |
| `customer_id` | `BIGINT` | `FOREIGN KEY -> core.customers(id)` | Review author. |
| `product_id` | `BIGINT` | `FOREIGN KEY -> inventory.products(id)` | Reviewed product catalog item. |
| `rating` | `INT` | `CHECK (rating BETWEEN 1 AND 5)` | Numerical rating score. |
| `comment` | `TEXT` | `NULL` | Written review text. |

---

## 4. Schema: inventory

### Table: `inventory.products`
Catalog merchandise items.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Product ID. |
| `category_id` | `BIGINT` | `FOREIGN KEY -> marketing.categories(id)` | Catalog category. |
| `supplier_id` | `BIGINT` | `FOREIGN KEY -> core.suppliers(id)` | Associated merchant supplier. |
| `name` | `VARCHAR(150)` | `NOT NULL` | Product name. |
| `sku` | `VARCHAR(50)` | `UNIQUE`, `CHECK (conforms to regex)` | Catalog SKU pattern. |
| `price` | `sales.price_type` | `NOT NULL` | Standard retail price. |
| `cost` | `sales.price_type` | `NOT NULL`, `CHECK (cost <= price)` | Wholesale purchase cost. |
| `description` | `TEXT` | `NULL` | Product specifications description. |
| `attributes` | `JSONB` | `NULL` | Dynamic product parameters. |
| `is_active` | `BOOLEAN` | `DEFAULT TRUE` | Catalogue listing flag. |

### Table: `inventory.warehouses`
Storage logistics facilities.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Warehouse ID. |
| `city_id` | `BIGINT` | `FOREIGN KEY -> core.cities(id)` | Facility city location. |
| `name` | `VARCHAR(100)` | `UNIQUE`, `NOT NULL` | Facility name. |
| `address` | `VARCHAR(255)` | `NOT NULL` | Physical street address. |
| `capacity` | `INT` | `CHECK (capacity > 0)` | Maximum cubic volume/units storage. |

### Table: `inventory.stocks`
Stock balance records for products in warehouses.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Stock ID. |
| `warehouse_id` | `BIGINT` | `FOREIGN KEY -> warehouses(id)` | Warehouse location. |
| `product_id` | `BIGINT` | `FOREIGN KEY -> products(id)` | Product item. |
| `quantity` | `INT` | `CHECK (quantity >= 0)` | Current units on-hand. |
| `reorder_level`| `INT` | `CHECK (reorder_level >= 0)` | Minimum threshold before restocking alert. |

### Table: `inventory.movements`
Stock transactions (inbound, outbound, transfers).

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Movement transaction ID. |
| `stock_id` | `BIGINT` | `FOREIGN KEY -> stocks(id)` | Stock record impacted. |
| `movement_type`| `inventory.movement_type_enum` | `NOT NULL` | INBOUND, OUTBOUND, TRANSFER, etc. |
| `quantity` | `INT` | `CHECK (quantity != 0)` | Net change in quantity. |
| `reference_id` | `BIGINT` | `NULL` | Link to order ID or processor employee ID. |
| `movement_date`| `TIMESTAMPTZ`| `DEFAULT CURRENT_TIMESTAMP` | Ledger timestamp. |

---

## 5. Schema: sales

### Table: `sales.orders`
Customer transaction orders.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Order ID. |
| `customer_id` | `BIGINT` | `FOREIGN KEY -> core.customers(id)` | Customer who purchased. |
| `employee_id` | `BIGINT` | `FOREIGN KEY -> hr.employees(id)` | Sales assistant (if applicable). |
| `promotion_id` | `BIGINT` | `FOREIGN KEY -> marketing.promotions(id)` | Campaign linked to purchase. |
| `coupon_id` | `BIGINT` | `FOREIGN KEY -> marketing.coupons(id)` | Coupon applied. |
| `order_date` | `TIMESTAMPTZ`| `NOT NULL` | Order timestamp. |
| `status` | `sales.order_status_enum` | `NOT NULL` | Pending, Processing, Shipped, etc. |
| `total_amount` | `sales.price_type` | `CHECK (total_amount >= 0)` | Gross catalog sum. |
| `discount_amount`| `sales.price_type`| `CHECK (discount_amount >= 0)` | Total discount deduction. |
| `net_amount` | `sales.price_type` | `CHECK (net_amount = total - discount)`| Net customer bill. |

### Table: `sales.order_items`
Detailed lines inside order baskets.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Item line ID. |
| `order_id` | `BIGINT` | `FOREIGN KEY -> sales.orders(id) ON DELETE CASCADE` | Associated order. |
| `product_id` | `BIGINT` | `FOREIGN KEY -> inventory.products(id)` | Purchased catalog product. |
| `quantity` | `INT` | `CHECK (quantity > 0)` | Quantity purchased. |
| `unit_price` | `sales.price_type` | `CHECK (unit_price > 0)` | Base retail unit price. |
| `discount_amount`| `sales.price_type`| `CHECK (discount_amount >= 0)` | Item discount value. |
| `subtotal` | `sales.price_type` | `CHECK (subtotal = (qty*price) - discount)` | Line item net subtotal. |

### Table: `sales.payments`
Completed invoice transactions.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Payment ID. |
| `order_id` | `BIGINT` | `FOREIGN KEY -> sales.orders(id)` | Paid order. |
| `payment_date` | `TIMESTAMPTZ`| `NOT NULL` | Payment transaction date. |
| `payment_method`| `sales.payment_method_enum` | `NOT NULL` | Credit Card, PayPal, Crypto, etc. |
| `amount` | `sales.price_type` | `CHECK (amount > 0)` | Paid amount. |
| `status` | `sales.payment_status_enum` | `NOT NULL` | Pending, Completed, Failed, Refunded. |

### Table: `sales.invoices`
Formal invoices.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Invoice ID. |
| `order_id` | `BIGINT` | `FOREIGN KEY -> sales.orders(id)` | Associated order. |
| `invoice_number`| `VARCHAR(50)` | `UNIQUE`, `CHECK (INV-YYYY-XXXXXXXX)` | Legal invoice string. |
| `issue_date` | `DATE` | `NOT NULL` | Billing issue date. |
| `due_date` | `DATE` | `CHECK (due_date >= issue_date)` | Terms payment due date. |
| `tax_amount` | `sales.price_type` | `CHECK (tax_amount >= 0)` | Applied value-added sales tax. |
| `total_amount` | `sales.price_type` | `CHECK (total_amount >= 0)` | Grand total including tax. |
| `status` | `sales.invoice_status_enum` | `NOT NULL` | Unpaid, Paid, Overdue, Cancelled. |

---

## 6. Schema: logistics

### Table: `logistics.shippers`
Logistics carriers (shipping companies).

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Carrier ID. |
| `name` | `VARCHAR(100)` | `UNIQUE`, `NOT NULL` | Carrier name (e.g., 'FedEx'). |
| `phone` | `core.phone_type` | `NOT NULL` | Contact number. |
| `email` | `core.email_type` | `NOT NULL` | Corporate contact email. |

### Table: `logistics.shipments`
Delivery transit tracking.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Shipment ID. |
| `order_id` | `BIGINT` | `FOREIGN KEY -> sales.orders(id)` | Sent order. |
| `shipper_id` | `BIGINT` | `FOREIGN KEY -> logistics.shippers(id)` | Logistics carrier. |
| `tracking_number`| `VARCHAR(100)`| `UNIQUE`, `CHECK (regex tracking)` | Package carrier tracking code. |
| `status` | `logistics.shipment_status_enum` | `NOT NULL` | In Transit, Out for Delivery, Delivered. |
| `shipment_date`| `TIMESTAMPTZ`| `NULL` | Departs warehouse timestamp. |
| `estimated_delivery`| `DATE` | `NULL` | Scheduled delivery date. |
| `delivery_date`| `TIMESTAMPTZ`| `CHECK (delivery >= shipment)` | Handover delivery timestamp. |

### Table: `logistics.returns`
Post-sales product returns ledger.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Return ID. |
| `order_item_id`| `BIGINT` | `FOREIGN KEY -> sales.order_items(id)` | Return line item. |
| `employee_id` | `BIGINT` | `FOREIGN KEY -> hr.employees(id)` | Clerk processing inspection. |
| `reason` | `logistics.return_reason_enum` | `NOT NULL` | Defective, Wrong Item, etc. |
| `status` | `logistics.return_status_enum` | `NOT NULL` | Initiated, Received, Inspected, etc. |
| `refund_amount`| `sales.price_type` | `CHECK (refund_amount >= 0)` | Credited refund amount. |
| `return_date` | `TIMESTAMPTZ`| `DEFAULT CURRENT_TIMESTAMP` | Hand-back timestamp. |

---

## 7. Schema: audit

### Table: `audit.logs`
Sensitive schema operation logs (inserts, updates, deletes).

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Log entry ID. |
| `table_name` | `VARCHAR(100)` | `NOT NULL` | Modified database table. |
| `action` | `audit.action_enum` | `NOT NULL` | INSERT, UPDATE, or DELETE. |
| `old_values` | `JSONB` | `NULL` | Prior record state payload. |
| `new_values` | `JSONB` | `NULL` | Target record state payload. |
| `performed_by` | `VARCHAR(100)` | `NOT NULL` | Session DB user executing statement. |
| `logged_at` | `TIMESTAMPTZ`| `DEFAULT CURRENT_TIMESTAMP` | Event timestamp. |

### Table: `audit.deleted_rows`
Archive containing entire rows that have been hard-deleted.

| Column | Data Type | Keys / Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | `PRIMARY KEY` | Archive record entry ID. |
| `table_name` | `VARCHAR(100)` | `NOT NULL` | Table row was deleted from. |
| `deleted_by` | `VARCHAR(100)` | `NOT NULL` | Database user performing delete. |
| `deleted_at` | `TIMESTAMPTZ`| `DEFAULT CURRENT_TIMESTAMP` | Deletion timestamp. |
| `original_id` | `BIGINT` | `NOT NULL` | PK value of the deleted row. |
| `original_uuid`| `UUID` | `NOT NULL` | UUID reference of the deleted row. |
| `original_data`| `JSONB` | `NOT NULL` | Complete contents of the deleted row. |
