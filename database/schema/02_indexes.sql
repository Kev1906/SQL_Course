-- ============================================================================
-- SQL Master Course - Database Indexes Definition (DataMartX)
-- Staff Data Engineer Design
-- ============================================================================

-- ----------------------------------------------------------------------------
-- B-TREE COMPOSITE INDEXES
-- ----------------------------------------------------------------------------

-- Index for searching customers by full name.
-- Rationale: Often queries will filter or sort by last name then first name.
-- A composite index satisfies both WHERE last_name = 'X' and WHERE last_name = 'X' AND first_name = 'Y'.
CREATE INDEX idx_customers_name_composite ON core.customers (last_name, first_name);
COMMENT ON INDEX idx_customers_name_composite IS 'B-Tree composite index for customer lookup by last name and first name. Optimizes search and alphabetical ordering.';

-- Index for orders by customer and order date.
-- Rationale: Used for loading a customer''s order history, sorted by order date descending.
-- By storing (customer_id, order_date DESC), PostgreSQL can perform an index scan to retrieve sorted history.
CREATE INDEX idx_orders_customer_date ON sales.orders (customer_id, order_date DESC);
COMMENT ON INDEX idx_orders_customer_date IS 'B-Tree composite index on customer_id and order_date (descending). Crucial for fetching customer purchase history fast.';

-- Index for order items by order and product.
-- Rationale: Foreign key columns are indexed to optimize joins. We add a composite index on (order_id, product_id)
-- though a unique constraint already covers this. We also index product_id for reverse joins.
CREATE INDEX idx_order_items_product ON sales.order_items (product_id);
COMMENT ON INDEX idx_order_items_product IS 'B-Tree index on product_id in order items to accelerate join queries aggregating sales by product.';

-- Index for cities by country.
-- Rationale: Helps fetch all cities belonging to a country.
CREATE INDEX idx_cities_country ON core.cities (country_id);
COMMENT ON INDEX idx_cities_country IS 'B-Tree index on country_id to speed up geographical country-to-city drills.';


-- ----------------------------------------------------------------------------
-- B-TREE PARTIAL INDEXES
-- ----------------------------------------------------------------------------

-- Index on active customers only.
-- Rationale: Most transactional operations query active customers.
-- Excluding inactive customers (where is_active = false) keeps the index size small and efficient.
CREATE INDEX idx_customers_active_partial ON core.customers (id) WHERE is_active = TRUE;
COMMENT ON INDEX idx_customers_active_partial IS 'Partial index covering active customers only. Minimizes size and speeds up active customer validation checks.';

-- Index on pending or processing orders.
-- Rationale: Operations teams monitor active orders (Pending/Processing).
-- Once delivered or cancelled, they are static. A partial index on active order statuses is extremely small and fast.
CREATE INDEX idx_orders_unfulfilled_partial ON sales.orders (id, status)
    WHERE status IN ('Pending', 'Processing');
COMMENT ON INDEX idx_orders_unfulfilled_partial IS 'Partial index for unfulfilled orders (Pending, Processing) to accelerate order fulfillment tracking.';

-- Index on unpaid or overdue invoices.
-- Rationale: Finance teams query unpaid or overdue invoices to send alerts.
-- Once paid, invoices are rarely searched for collections.
CREATE INDEX idx_invoices_unpaid_partial ON sales.invoices (id, status)
    WHERE status IN ('Unpaid', 'Overdue');
COMMENT ON INDEX idx_invoices_unpaid_partial IS 'Partial index for outstanding collections (Unpaid, Overdue) to expedite accounts receivable reports.';

-- Index on active promotions.
-- Rationale: Marketing coupon validation only needs active promotions.
CREATE INDEX idx_promotions_active_partial ON marketing.promotions (id)
    WHERE end_date >= CURRENT_DATE;
COMMENT ON INDEX idx_promotions_active_partial IS 'Partial index for active/upcoming promotions based on dates.';


-- ----------------------------------------------------------------------------
-- GIN (GENERALIZED INVERTED INDEX) FOR JSONB & TEXT SEARCH
-- ----------------------------------------------------------------------------

-- GIN index on product attributes.
-- Rationale: Product specifications (attributes JSONB) vary (color, size, memory, capacity, weight).
-- A jsonb_path_ops GIN index supports highly efficient path existence and equality queries (e.g. attributes @> ''{"color": "red"}'').
CREATE INDEX idx_products_attributes_gin ON inventory.products USING gin (attributes jsonb_path_ops);
COMMENT ON INDEX idx_products_attributes_gin IS 'GIN index on JSONB attributes using jsonb_path_ops. Crucial for sub-millisecond filtering on dynamic product attributes.';

-- GIN index on product name and description for text search.
-- Rationale: Supports fuzzy search and full-text search (FTS) on catalog.
-- We cast name and description to tsvector.
CREATE INDEX idx_products_fts_gin ON inventory.products USING gin (to_tsvector('english', name || ' ' || COALESCE(description, '')));
COMMENT ON INDEX idx_products_fts_gin IS 'GIN index on text search vector of product name and description. Powering fast search queries in the marketplace catalog.';


-- ----------------------------------------------------------------------------
-- HASH AND ADDITIONAL B-TREE INDEXES
-- ----------------------------------------------------------------------------

-- Index for suppliers by city.
-- Rationale: Speeds up logistics grouping.
CREATE INDEX idx_suppliers_city ON core.suppliers (city_id);
COMMENT ON INDEX idx_suppliers_city IS 'B-Tree index on supplier city_id to support warehouse/supplier proximity calculations.';

-- Index for inventory movements.
-- Rationale: Warehousing logs grow very fast. Sorting movements by date or filtering by type is frequent.
CREATE INDEX idx_movements_date_type ON inventory.movements (stock_id, movement_date DESC);
COMMENT ON INDEX idx_movements_date_type IS 'B-Tree index on stock_id and movement_date DESC for tracking stock history ledger.';
