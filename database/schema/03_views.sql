-- ============================================================================
-- SQL Master Course - Views & Materialized Views Definition (DataMartX)
-- Staff Data Engineer Design
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STANDARD VIEWS
-- ----------------------------------------------------------------------------

-- 1. Customer Lifetime Value (CLV) View
-- Rationale: Computes customer cohort metrics, purchase counts, and total monetary value.
CREATE OR REPLACE VIEW analytics.vw_customer_lifetime_value AS
SELECT
    c.id AS customer_id,
    c.uuid AS customer_uuid,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    c.segment,
    c.birth_date,
    city.name AS city_name,
    country.name AS country_name,
    COUNT(o.id) AS total_orders,
    COALESCE(SUM(o.net_amount), 0.00) AS total_spent,
    COALESCE(AVG(o.net_amount), 0.00) AS average_order_value,
    COALESCE(SUM(o.discount_amount), 0.00) AS total_discounts_received,
    MIN(o.order_date) AS first_order_date,
    MAX(o.order_date) AS last_order_date,
    EXTRACT(DAY FROM (MAX(o.order_date) - MIN(o.order_date))) AS customer_tenure_days
FROM core.customers c
INNER JOIN core.cities city ON c.city_id = city.id
INNER JOIN core.countries country ON city.country_id = country.id
LEFT JOIN sales.orders o ON c.id = o.customer_id AND o.status NOT IN ('Cancelled')
GROUP BY c.id, c.uuid, c.first_name, c.last_name, c.email, c.segment, c.birth_date, city.name, country.name;

COMMENT ON VIEW analytics.vw_customer_lifetime_value IS 'Calculates Customer Lifetime Value (CLV) aggregates, grouping by country and segment.';


-- 2. Recursive Org Chart (Employee Hierarchy) View
-- Rationale: Demonstrates recursive CTEs. Walks the employee manager tree.
CREATE OR REPLACE VIEW analytics.vw_employee_hierarchy AS
WITH RECURSIVE org_chart AS (
    -- Anchor member: CEO or employees with no manager
    SELECT
        id,
        first_name || ' ' || last_name AS employee_name,
        job_title,
        salary,
        department_id,
        manager_id,
        1 AS hierarchy_level,
        ARRAY[id] AS path_ids
    FROM hr.employees
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive member: employees with a manager
    SELECT
        e.id,
        e.first_name || ' ' || e.last_name AS employee_name,
        e.job_title,
        e.salary,
        e.department_id,
        e.manager_id,
        oc.hierarchy_level + 1 AS hierarchy_level,
        oc.path_ids || e.id AS path_ids
    FROM hr.employees e
    INNER JOIN org_chart oc ON e.manager_id = oc.id
)
SELECT
    oc.id AS employee_id,
    oc.employee_name,
    oc.job_title,
    oc.salary,
    d.name AS department_name,
    oc.manager_id,
    mgr.first_name || ' ' || mgr.last_name AS manager_name,
    oc.hierarchy_level,
    oc.path_ids
FROM org_chart oc
INNER JOIN hr.departments d ON oc.department_id = d.id
LEFT JOIN hr.employees mgr ON oc.manager_id = mgr.id
ORDER BY oc.path_ids;

COMMENT ON VIEW analytics.vw_employee_hierarchy IS 'Displays employee reporting hierarchy using recursive queries, level depth, and path tracing.';


-- 3. Daily Sales Performance View
-- Rationale: High-level KPI view showing daily sales broken down by country and category.
CREATE OR REPLACE VIEW analytics.vw_daily_sales AS
SELECT
    CAST(o.order_date AS DATE) AS sales_date,
    country.name AS country_name,
    cat.name AS category_name,
    COUNT(DISTINCT o.id) AS orders_count,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.quantity * oi.unit_price) AS gross_revenue,
    SUM(oi.discount_amount) AS discounts_applied,
    SUM(oi.subtotal) AS net_revenue
FROM sales.orders o
INNER JOIN sales.order_items oi ON o.id = oi.order_id
INNER JOIN inventory.products p ON oi.product_id = p.id
INNER JOIN marketing.categories cat ON p.category_id = cat.id
INNER JOIN core.customers c ON o.customer_id = c.id
INNER JOIN core.cities city ON c.city_id = city.id
INNER JOIN core.countries country ON city.country_id = country.id
WHERE o.status NOT IN ('Cancelled')
GROUP BY CAST(o.order_date AS DATE), country.name, cat.name;

COMMENT ON VIEW analytics.vw_daily_sales IS 'Daily sales performance ledger aggregated by country and product category.';


-- ----------------------------------------------------------------------------
-- MATERIALIZED VIEWS
-- ----------------------------------------------------------------------------

-- 1. Materialized View for Stock Status
-- Rationale: Stock audits require heavy computations (sums, costs, price valuations, reorder check).
-- Recomputing on every query slows down the warehouse application. Materializing it speeds up operations.
CREATE MATERIALIZED VIEW analytics.mv_stock_status AS
SELECT
    s.id AS stock_id,
    w.name AS warehouse_name,
    c.name AS warehouse_city,
    p.name AS product_name,
    p.sku AS product_sku,
    cat.name AS category_name,
    s.quantity AS current_stock,
    s.reorder_level,
    CASE 
        WHEN s.quantity = 0 THEN 'OUT OF STOCK'
        WHEN s.quantity <= s.reorder_level THEN 'REORDER ALERT'
        ELSE 'OK'
    END AS inventory_health,
    p.cost AS unit_cost,
    p.price AS unit_price,
    (s.quantity * p.cost) AS stock_valuation_cost,
    (s.quantity * p.price) AS stock_valuation_retail
FROM inventory.stocks s
INNER JOIN inventory.warehouses w ON s.warehouse_id = w.id
INNER JOIN core.cities c ON w.city_id = c.id
INNER JOIN inventory.products p ON s.product_id = p.id
INNER JOIN marketing.categories cat ON p.category_id = cat.id;

-- Unique index to allow CONCURRENT REFRESH
CREATE UNIQUE INDEX idx_mv_stock_status_pk ON analytics.mv_stock_status (stock_id);

COMMENT ON MATERIALIZED VIEW analytics.mv_stock_status IS 'Materialized inventory health evaluation and valuation by product and warehouse.';


-- 2. Materialized View for Slow-Moving Inventory (Aged Stock)
-- Rationale: Identifies products with no sales or movement for over 90 days.
-- Involves searching large transactional logs (`movements`).
CREATE MATERIALIZED VIEW analytics.mv_slow_moving_inventory AS
WITH last_movement AS (
    SELECT
        stock_id,
        MAX(movement_date) AS last_activity_date
    FROM inventory.movements
    GROUP BY stock_id
)
SELECT
    ss.stock_id,
    ss.warehouse_name,
    ss.product_name,
    ss.product_sku,
    ss.category_name,
    ss.current_stock,
    ss.stock_valuation_cost,
    COALESCE(lm.last_activity_date, ss.stock_id::text::timestamp) AS last_movement_date,
    CURRENT_DATE - COALESCE(lm.last_activity_date, NOW())::DATE AS days_idle
FROM analytics.mv_stock_status ss
LEFT JOIN last_movement lm ON ss.stock_id = lm.stock_id
WHERE ss.current_stock > 0
  AND (lm.last_activity_date IS NULL OR lm.last_activity_date < CURRENT_DATE - INTERVAL '90 days');

CREATE UNIQUE INDEX idx_mv_slow_moving_pk ON analytics.mv_slow_moving_inventory (stock_id);

COMMENT ON MATERIALIZED VIEW analytics.mv_slow_moving_inventory IS 'Tracks slow-moving items with more than 90 days of absolute inactivity and their cost valuation.';
