-- ============================================================================
-- SQL Master Course - Database Schema Definition (DataMartX)
-- Staff Data Engineer Design
-- ============================================================================

-- Enable pgcrypto extension for UUID generation if needed (PostgreSQL 17 has gen_random_uuid() built-in)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. SCHEMA CREATION
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS hr;
CREATE SCHEMA IF NOT EXISTS marketing;
CREATE SCHEMA IF NOT EXISTS inventory;
CREATE SCHEMA IF NOT EXISTS sales;
CREATE SCHEMA IF NOT EXISTS logistics;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS audit;

-- ============================================================================
-- 2. DOMAINS AND CUSTOM TYPES
-- ============================================================================
CREATE DOMAIN core.email_type AS VARCHAR(150)
    CHECK (VALUE ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$');

CREATE DOMAIN core.phone_type AS VARCHAR(50)
    CHECK (VALUE ~* '^\+?[0-9\s\-()]{7,25}$');

CREATE DOMAIN sales.price_type AS NUMERIC(12, 2)
    CHECK (VALUE >= 0.00);

-- Enums
CREATE TYPE core.gender_enum AS ENUM ('Male', 'Female', 'Other', 'Prefer Not to Say');
CREATE TYPE core.segment_enum AS ENUM ('Premium', 'Standard', 'Occasional', 'Sports Enthusiast');
CREATE TYPE sales.order_status_enum AS ENUM ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled', 'Returned');
CREATE TYPE sales.payment_method_enum AS ENUM ('Credit Card', 'PayPal', 'Bank Transfer', 'Cryptocurrency', 'Gift Card');
CREATE TYPE sales.payment_status_enum AS ENUM ('Pending', 'Completed', 'Failed', 'Refunded');
CREATE TYPE sales.invoice_status_enum AS ENUM ('Unpaid', 'Paid', 'Overdue', 'Cancelled');
CREATE TYPE inventory.movement_type_enum AS ENUM ('INBOUND', 'OUTBOUND', 'TRANSFER_IN', 'TRANSFER_OUT', 'ADJUSTMENT');
CREATE TYPE logistics.shipment_status_enum AS ENUM ('In Transit', 'Out for Delivery', 'Delivered', 'Failed Delivery', 'Returned');
CREATE TYPE logistics.return_reason_enum AS ENUM ('Defective', 'Wrong Item', 'Size Mismatch', 'Not as Described', 'Buyer Remorse');
CREATE TYPE logistics.return_status_enum AS ENUM ('Initiated', 'Received', 'Inspected', 'Approved', 'Rejected', 'Completed');
CREATE TYPE audit.action_enum AS ENUM ('INSERT', 'UPDATE', 'DELETE');

-- ============================================================================
-- 3. TABLE DEFINITIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CORE SCHEMA
-- ----------------------------------------------------------------------------

CREATE TABLE core.countries (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    code CHAR(2) NOT NULL UNIQUE CHECK (char_length(code) = 2),
    name VARCHAR(100) NOT NULL UNIQUE,
    region VARCHAR(50) NOT NULL CHECK (region IN ('North America', 'South America', 'Europe', 'Asia', 'Africa', 'Oceania')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE core.cities (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    country_id BIGINT NOT NULL REFERENCES core.countries(id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL,
    state_province VARCHAR(100) NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_country_city_state UNIQUE (country_id, name, state_province)
);

CREATE TABLE core.customers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    city_id BIGINT NOT NULL REFERENCES core.cities(id) ON DELETE RESTRICT,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email core.email_type NOT NULL UNIQUE,
    phone core.phone_type NULL,
    gender core.gender_enum NOT NULL,
    segment core.segment_enum NOT NULL DEFAULT 'Standard',
    birth_date DATE NOT NULL CHECK (birth_date <= CURRENT_DATE - INTERVAL '18 years'),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE core.suppliers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    city_id BIGINT NOT NULL REFERENCES core.cities(id) ON DELETE RESTRICT,
    name VARCHAR(150) NOT NULL UNIQUE,
    contact_name VARCHAR(150) NOT NULL,
    email core.email_type NOT NULL,
    phone core.phone_type NOT NULL,
    category_focus VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- ----------------------------------------------------------------------------
-- HR SCHEMA (Circular reference for manager_id resolved via ALTER TABLE)
-- ----------------------------------------------------------------------------

CREATE TABLE hr.departments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    budget NUMERIC(15, 2) NOT NULL CHECK (budget > 0.00),
    manager_id BIGINT NULL, -- Added FK constraint later to avoid circular reference
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE hr.employees (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    department_id BIGINT NOT NULL REFERENCES hr.departments(id) ON DELETE RESTRICT,
    manager_id BIGINT NULL REFERENCES hr.employees(id) ON DELETE SET NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email core.email_type NOT NULL UNIQUE,
    job_title VARCHAR(100) NOT NULL,
    salary NUMERIC(12, 2) NOT NULL CHECK (salary > 0.00),
    hire_date DATE NOT NULL CHECK (hire_date <= CURRENT_DATE),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Add manager FK constraint to departments
ALTER TABLE hr.departments
    ADD CONSTRAINT fk_department_manager FOREIGN KEY (manager_id) REFERENCES hr.employees(id) ON DELETE SET NULL;

-- ----------------------------------------------------------------------------
-- MARKETING SCHEMA
-- ----------------------------------------------------------------------------

CREATE TABLE marketing.categories (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    parent_id BIGINT NULL REFERENCES marketing.categories(id) ON DELETE SET NULL,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE marketing.promotions (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    discount_percentage NUMERIC(5, 2) NOT NULL CHECK (discount_percentage > 0.00 AND discount_percentage <= 100.00),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_promotion_dates CHECK (end_date >= start_date)
);

CREATE TABLE marketing.coupons (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    promotion_id BIGINT NULL REFERENCES marketing.promotions(id) ON DELETE SET NULL,
    code VARCHAR(50) NOT NULL UNIQUE CHECK (char_length(code) >= 3),
    discount_amount sales.price_type NOT NULL,
    min_purchase_amount sales.price_type NOT NULL DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- ----------------------------------------------------------------------------
-- INVENTORY SCHEMA
-- ----------------------------------------------------------------------------

CREATE TABLE inventory.products (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    category_id BIGINT NOT NULL REFERENCES marketing.categories(id) ON DELETE RESTRICT,
    supplier_id BIGINT NOT NULL REFERENCES core.suppliers(id) ON DELETE RESTRICT,
    name VARCHAR(150) NOT NULL,
    sku VARCHAR(50) NOT NULL UNIQUE CHECK (sku ~* '^[A-Z0-9-]{8,20}$'),
    price sales.price_type NOT NULL,
    cost sales.price_type NOT NULL,
    description TEXT NULL,
    attributes JSONB NULL, -- Flexible specifications (color, weight, etc.)
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_price_greater_than_cost CHECK (price >= cost)
);

CREATE TABLE inventory.warehouses (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    city_id BIGINT NOT NULL REFERENCES core.cities(id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL UNIQUE,
    address VARCHAR(255) NOT NULL,
    capacity INT NOT NULL CHECK (capacity > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE inventory.stocks (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    warehouse_id BIGINT NOT NULL REFERENCES inventory.warehouses(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES inventory.products(id) ON DELETE RESTRICT,
    quantity INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    reorder_level INT NOT NULL DEFAULT 10 CHECK (reorder_level >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_warehouse_product UNIQUE (warehouse_id, product_id)
);

CREATE TABLE inventory.movements (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    stock_id BIGINT NOT NULL REFERENCES inventory.stocks(id) ON DELETE CASCADE,
    movement_type inventory.movement_type_enum NOT NULL,
    quantity INT NOT NULL CHECK (quantity <> 0), -- positive for INBOUND/TRANSFER_IN, negative for OUTBOUND/TRANSFER_OUT/ADJUSTMENT
    reference_id BIGINT NULL, -- e.g., sales.orders(id) or logistics.returns(id) (loose coupling via bigint)
    movement_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- ----------------------------------------------------------------------------
-- MARKETING REVIEWS (Linked to customers and products)
-- ----------------------------------------------------------------------------

CREATE TABLE marketing.reviews (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    customer_id BIGINT NOT NULL REFERENCES core.customers(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES inventory.products(id) ON DELETE CASCADE,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_customer_product_review UNIQUE (customer_id, product_id)
);

-- ----------------------------------------------------------------------------
-- SALES SCHEMA
-- ----------------------------------------------------------------------------

CREATE TABLE sales.orders (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    customer_id BIGINT NOT NULL REFERENCES core.customers(id) ON DELETE RESTRICT,
    employee_id BIGINT NULL REFERENCES hr.employees(id) ON DELETE SET NULL,
    promotion_id BIGINT NULL REFERENCES marketing.promotions(id) ON DELETE SET NULL,
    coupon_id BIGINT NULL REFERENCES marketing.coupons(id) ON DELETE SET NULL,
    order_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status sales.order_status_enum NOT NULL DEFAULT 'Pending',
    total_amount sales.price_type NOT NULL DEFAULT 0.00,
    discount_amount sales.price_type NOT NULL DEFAULT 0.00,
    net_amount sales.price_type NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_net_amount CHECK (net_amount = total_amount - discount_amount)
);

CREATE TABLE sales.order_items (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    order_id BIGINT NOT NULL REFERENCES sales.orders(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES inventory.products(id) ON DELETE RESTRICT,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price sales.price_type NOT NULL,
    discount_amount sales.price_type NOT NULL DEFAULT 0.00,
    subtotal sales.price_type NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_order_product UNIQUE (order_id, product_id),
    CONSTRAINT chk_subtotal CHECK (subtotal = (quantity * unit_price) - discount_amount)
);

CREATE TABLE sales.payments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    order_id BIGINT NOT NULL REFERENCES sales.orders(id) ON DELETE RESTRICT,
    payment_date TIMESTAMP WITH TIME ZONE NOT NULL,
    payment_method sales.payment_method_enum NOT NULL,
    amount sales.price_type NOT NULL,
    status sales.payment_status_enum NOT NULL DEFAULT 'Pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE sales.invoices (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    order_id BIGINT NOT NULL REFERENCES sales.orders(id) ON DELETE RESTRICT,
    invoice_number VARCHAR(50) NOT NULL UNIQUE CHECK (invoice_number ~* '^INV-\d{4}-\d{8}$'),
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    tax_amount sales.price_type NOT NULL DEFAULT 0.00,
    total_amount sales.price_type NOT NULL,
    status sales.invoice_status_enum NOT NULL DEFAULT 'Unpaid',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_invoice_dates CHECK (due_date >= issue_date)
);

-- ----------------------------------------------------------------------------
-- LOGISTICS SCHEMA
-- ----------------------------------------------------------------------------

CREATE TABLE logistics.shippers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    phone core.phone_type NOT NULL,
    email core.email_type NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE logistics.shipments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    order_id BIGINT NOT NULL REFERENCES sales.orders(id) ON DELETE RESTRICT,
    shipper_id BIGINT NOT NULL REFERENCES logistics.shippers(id) ON DELETE RESTRICT,
    tracking_number VARCHAR(100) NOT NULL UNIQUE CHECK (tracking_number ~* '^[A-Z0-9-]{12,24}$'),
    status logistics.shipment_status_enum NOT NULL DEFAULT 'In Transit',
    shipment_date TIMESTAMP WITH TIME ZONE NULL,
    estimated_delivery DATE NULL,
    delivery_date TIMESTAMP WITH TIME ZONE NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_delivery_date CHECK (delivery_date >= shipment_date)
);

CREATE TABLE logistics.returns (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    order_item_id BIGINT NOT NULL REFERENCES sales.order_items(id) ON DELETE RESTRICT,
    employee_id BIGINT NULL REFERENCES hr.employees(id) ON DELETE SET NULL, -- HR employee processing
    reason logistics.return_reason_enum NOT NULL,
    status logistics.return_status_enum NOT NULL DEFAULT 'Initiated',
    refund_amount sales.price_type NOT NULL DEFAULT 0.00,
    return_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- ----------------------------------------------------------------------------
-- AUDIT SCHEMA
-- ----------------------------------------------------------------------------

CREATE TABLE audit.logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    action audit.action_enum NOT NULL,
    old_values JSONB NULL,
    new_values JSONB NULL,
    performed_by VARCHAR(100) NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE audit.deleted_rows (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    table_name VARCHAR(100) NOT NULL,
    deleted_by VARCHAR(100) NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    original_id BIGINT NOT NULL,
    original_uuid UUID NOT NULL,
    original_data JSONB NOT NULL
);
