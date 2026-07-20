-- ============================================================================
-- SQL Master Course - Day 004 Exercises (DataMartX) - SOLUCIONES
-- Topic: UNION, INTERSECT, EXCEPT
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Ejercicio 1 -- Ticket MKT-112: Campaña de reactivación omnicanal
-- ----------------------------------------------------------------------------

-- Solución usando UNION (restricción del enunciado)
-- UNION elimina duplicados automáticamente, garantizando unicidad
SELECT 
    'Premium Inactive' AS group_label,
    c.first_name || ' ' || c.last_name AS full_name,
    c.email,
    c.segment,
    SUM(o.net_amount) AS total_spent,
    (CURRENT_DATE - MAX(o.order_date)::date) AS days_since_last_purchase
FROM core.customers c
JOIN sales.orders o ON o.customer_id = c.id
WHERE o.status = 'Delivered'
    AND c.segment = 'Premium'
GROUP BY c.id, c.first_name, c.last_name, c.email, c.segment
HAVING (CURRENT_DATE - MAX(o.order_date)::date) >= 180

UNION

SELECT 
    'Standard Dormant' AS group_label,
    c.first_name || ' ' || c.last_name AS full_name,
    c.email,
    c.segment,
    SUM(o.net_amount) AS total_spent,
    (CURRENT_DATE - MAX(o.order_date)::date) AS days_since_last_purchase
FROM core.customers c
JOIN sales.orders o ON o.customer_id = c.id
WHERE o.status = 'Delivered'
    AND c.segment = 'Standard'
GROUP BY c.id, c.first_name, c.last_name, c.email, c.segment
HAVING (CURRENT_DATE - MAX(o.order_date)::date) > 90
    AND SUM(o.net_amount) > 5000

ORDER BY group_label ASC, days_since_last_purchase DESC;

-- ----------------------------------------------------------------------------
-- Ejercicio 2 -- Ticket CAT-041: Categorías estrella en todos los trimestres
-- ----------------------------------------------------------------------------

-- Solución: INTERSECT solo con category_id, luego JOIN para calcular ventas
WITH star_categories AS (
    -- Categorías estrella en Q1
    SELECT p.category_id
    FROM marketing.categories cat
    JOIN inventory.products p ON cat.id = p.category_id
    JOIN sales.order_items oi ON oi.product_id = p.id
    JOIN sales.orders o ON o.id = oi.order_id
    WHERE o.status <> 'Cancelled' 
        AND o.order_date >= '2025-01-01' 
        AND o.order_date < '2025-04-01'
    GROUP BY p.category_id
    HAVING SUM(oi.subtotal - COALESCE(oi.discount_amount, 0)) >= 10000
    
    INTERSECT
    
    -- Categorías estrella en Q2
    SELECT p.category_id
    FROM marketing.categories cat
    JOIN inventory.products p ON cat.id = p.category_id
    JOIN sales.order_items oi ON oi.product_id = p.id
    JOIN sales.orders o ON o.id = oi.order_id
    WHERE o.status <> 'Cancelled' 
        AND o.order_date >= '2025-04-01' 
        AND o.order_date < '2025-07-01'
    GROUP BY p.category_id
    HAVING SUM(oi.subtotal - COALESCE(oi.discount_amount, 0)) >= 10000
    
    INTERSECT
    
    -- Categorías estrella en Q3
    SELECT p.category_id
    FROM marketing.categories cat
    JOIN inventory.products p ON cat.id = p.category_id
    JOIN sales.order_items oi ON oi.product_id = p.id
    JOIN sales.orders o ON o.id = oi.order_id
    WHERE o.status <> 'Cancelled' 
        AND o.order_date >= '2025-07-01' 
        AND o.order_date < '2025-10-01'
    GROUP BY p.category_id
    HAVING SUM(oi.subtotal - COALESCE(oi.discount_amount, 0)) >= 10000
    
    INTERSECT
    
    -- Categorías estrella en Q4
    SELECT p.category_id
    FROM marketing.categories cat
    JOIN inventory.products p ON cat.id = p.category_id
    JOIN sales.order_items oi ON oi.product_id = p.id
    JOIN sales.orders o ON o.id = oi.order_id
    WHERE o.status <> 'Cancelled' 
        AND o.order_date >= '2025-10-01' 
        AND o.order_date < '2026-01-01'
    GROUP BY p.category_id
    HAVING SUM(oi.subtotal - COALESCE(oi.discount_amount, 0)) >= 10000
),
quarterly_sales AS (
    SELECT 
        cat.id AS category_id,
        cat.name AS category_name,
        SUM(CASE WHEN o.order_date >= '2025-01-01' AND o.order_date < '2025-04-01' 
            THEN oi.subtotal - COALESCE(oi.discount_amount, 0) ELSE 0 END) AS q1_sales,
        SUM(CASE WHEN o.order_date >= '2025-04-01' AND o.order_date < '2025-07-01' 
            THEN oi.subtotal - COALESCE(oi.discount_amount, 0) ELSE 0 END) AS q2_sales,
        SUM(CASE WHEN o.order_date >= '2025-07-01' AND o.order_date < '2025-10-01' 
            THEN oi.subtotal - COALESCE(oi.discount_amount, 0) ELSE 0 END) AS q3_sales,
        SUM(CASE WHEN o.order_date >= '2025-10-01' AND o.order_date < '2026-01-01' 
            THEN oi.subtotal - COALESCE(oi.discount_amount, 0) ELSE 0 END) AS q4_sales
    FROM marketing.categories cat
    JOIN inventory.products p ON cat.id = p.category_id
    JOIN sales.order_items oi ON oi.product_id = p.id
    JOIN sales.orders o ON o.id = oi.order_id
    WHERE o.status <> 'Cancelled' 
        AND o.order_date >= '2025-01-01' 
        AND o.order_date < '2026-01-01'
    GROUP BY cat.id, cat.name
)
SELECT 
    qs.category_name,
    qs.q1_sales,
    qs.q2_sales,
    qs.q3_sales,
    qs.q4_sales,
    (qs.q1_sales + qs.q2_sales + qs.q3_sales + qs.q4_sales) AS total_annual_sales
FROM quarterly_sales qs
JOIN star_categories sc ON sc.category_id = qs.category_id
ORDER BY total_annual_sales DESC;

-- ----------------------------------------------------------------------------
-- Ejercicio 3 -- Ticket OPS-072: Huérfanos de inventario cross-warehouse
-- ----------------------------------------------------------------------------

-- Solución: EXCEPT para encontrar productos con stock global pero sin stock en país del proveedor
WITH products_with_global_stock AS (
    SELECT 
        p.id AS product_id,
        p.name AS product_name,
        p.sku,
        s.name AS supplier_name,
        co.name AS supplier_country,
        co.id AS supplier_country_id,
        SUM(st.quantity) AS total_stock_global,
        0 AS stock_in_supplier_country
    FROM inventory.products p
    JOIN core.suppliers s ON s.id = p.supplier_id
    JOIN core.cities ci ON ci.id = s.city_id
    JOIN core.countries co ON co.id = ci.country_id
    JOIN inventory.stocks st ON st.product_id = p.id
    WHERE p.is_active = TRUE
        AND st.quantity > 0
    GROUP BY p.id, p.name, p.sku, s.name, co.name, co.id
    HAVING SUM(st.quantity) > 0
),
products_with_stock_in_supplier_country AS (
    SELECT 
        p.id AS product_id
    FROM inventory.products p
    JOIN core.suppliers s ON s.id = p.supplier_id
    JOIN core.cities ci_supplier ON ci_supplier.id = s.city_id
    JOIN inventory.stocks st ON st.product_id = p.id
    JOIN inventory.warehouses w ON w.id = st.warehouse_id
    JOIN core.cities ci_warehouse ON ci_warehouse.id = w.city_id
    WHERE p.is_active = TRUE
        AND st.quantity > 0
        AND ci_warehouse.country_id = ci_supplier.country_id
    GROUP BY p.id
)
SELECT 
    pgs.product_name,
    pgs.sku,
    pgs.supplier_name,
    pgs.supplier_country,
    pgs.total_stock_global,
    pgs.stock_in_supplier_country
FROM products_with_global_stock pgs
WHERE pgs.product_id IN (
    SELECT product_id FROM products_with_global_stock
    EXCEPT
    SELECT product_id FROM products_with_stock_in_supplier_country
)
ORDER BY pgs.total_stock_global DESC;
