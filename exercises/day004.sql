-- ============================================================================
-- SQL Master Course - Day 004 Exercises (DataMartX)
-- Topic: UNION, INTERSECT, EXCEPT
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Ejercicio 1 -- Ticket MKT-112: Campaña de reactivación omnicanal
-- Solicitante: Directora de Marketing
-- Prioridad: Alta
-- ----------------------------------------------------------------------------

-- Queremos lanzar una campaña de reactivación dirigida a dos segmentos
-- específicos de clientes. Necesito UNA sola lista consolidada con:
--
-- GRUPO A: Clientes "Premium" que NO han comprado en los últimos 180 días.
-- GRUPO B: Clientes "Standard" que gastaron más de $5,000 en total pero
--           cuya última compra fue hace más de 90 días.
--
-- REQUISITOS:
-- - Mostrar: group_label ('Premium Inactive' / 'Standard Dormant'), full_name,
--   email, segment, total_spent, days_since_last_purchase.
-- - days_since_last_purchase debe calcularse contra CURRENT_DATE.
-- - Si un cliente aparece en AMBOS grupos, debe aparecer UNA sola vez
--   (etiquetado como el grupo que encontraste primero en tu lógica).
-- - SIN duplicados en el resultado final.
-- - Ordenar por group_label, luego days_since_last_purchase descendente.
--
-- RESTRICCIÓN: Usa UNION (no UNION ALL).

-- Escribe tu consulta aquí abajo:
SELECT 
	'Premium Inactive' as group_label,
	c.first_name || ' ' || c.last_name as full_name,
	c.email,
	c.segment,
	SUM(o.net_amount) as total_spent,
	EXTRACT(DAY FROM CURRENT_DATE - MAX(o.order_date)) as days_since_last_purchase
FROM core.customers c
JOIN sales.orders o ON o.customer_id = c.id
WHERE o.status = 'Delivered' AND c.segment = 'Premium'
GROUP by c.first_name,c.last_name,c.email,c.segment
HAVING EXTRACT(DAY FROM CURRENT_DATE - MAX(o.order_date)) >= 180

UNION

SELECT 
	'Standard Dormant' as group_label,
	c.first_name || ' ' || c.last_name as full_name,
	c.email,
	c.segment,
	SUM(o.net_amount) as total_spent,
	EXTRACT(DAY FROM CURRENT_DATE - MAX(o.order_date)) as days_since_last_purchase
FROM core.customers c
JOIN sales.orders o ON o.customer_id = c.id
WHERE o.status = 'Delivered' AND c.segment = 'Standard'
GROUP by c.first_name,c.last_name,c.email,c.segment
HAVING EXTRACT(DAY FROM CURRENT_DATE - MAX(o.order_date)) > 90 AND SUM(o.net_amount)>5000

ORDER BY group_label ASC, days_since_last_purchase DESC;

WITH customer_activity AS (
    SELECT 
        c.id,
        c.first_name || ' ' || c.last_name AS full_name,
        c.email,
        c.segment,
        SUM(o.net_amount) AS total_spent,
        (CURRENT_DATE - MAX(o.order_date)::date) AS days_since_last_purchase
    FROM core.customers c
    JOIN sales.orders o ON o.customer_id = c.id
    WHERE o.status = 'Delivered'
        AND c.segment IN ('Premium', 'Standard')
    GROUP BY c.id, c.first_name, c.last_name, c.email, c.segment
),
classified_customers AS (
    SELECT 
        id,
        full_name,
        email,
        segment,
        total_spent,
        days_since_last_purchase,
        CASE 
            WHEN segment = 'Premium' AND days_since_last_purchase >= 180 THEN 'Premium Inactive'
            WHEN segment = 'Standard' AND days_since_last_purchase > 90 AND total_spent > 5000 THEN 'Standard Dormant'
            ELSE NULL
        END AS group_label
    FROM customer_activity
    WHERE (segment = 'Premium' AND days_since_last_purchase >= 180)
        OR (segment = 'Standard' AND days_since_last_purchase > 90 AND total_spent > 5000)
)
SELECT 
    group_label,
    full_name,
    email,
    segment,
    total_spent,
    days_since_last_purchase
FROM classified_customers
WHERE group_label IS NOT NULL
ORDER BY group_label ASC, days_since_last_purchase DESC
LIMIT 5;

-- ----------------------------------------------------------------------------
-- Ejercicio 2 -- Ticket CAT-041: Categorías estrella en todos los trimestres
-- Solicitante: Category Manager
-- Prioridad: Alta
-- ----------------------------------------------------------------------------

-- El VP de Producto quiere identificar las categorías que han sido "estrella"
-- durante TODO el año 2025. Una categoría es "estrella" en un trimestre si
-- generó al menos $10,000 en ventas netas (net_amount, excluyendo canceladas).
--
-- Necesito las categorías que fueron estrella en LOS CUATRO trimestres de 2025.
--
-- REQUISITOS:
-- - Mostrar: category_name, q1_sales, q2_sales, q3_sales, q4_sales,
--   total_annual_sales.
-- - Los trimestres son: Q1 (Ene-Mar), Q2 (Abr-Jun), Q3 (Jul-Sep), Q4 (Oct-Dic).
-- - La categoría debe cumplir el mínimo de $10,000 en CADA trimestre.
-- - Ordenar por total_annual_sales descendente.
--
-- RESTRICCIÓN: Usa INTERSECT como parte de tu solución. Piensa en cómo
-- combinar INTERSECT con agregaciones.

-- Escribe tu consulta aquí abajo:

SELECT
	cat."name" as category_name,
	SUM(oi.subtotal - COALESCE(oi.discount_amount,0)) as q1_sales,
	0 as q2_sales,
	0 as q3_sales,
	0 as q4_sales
FROM marketing.categories cat
JOIN inventory.products p ON cat.id = p.category_id
JOIN sales.order_items oi on oi.product_id = p.id
JOIN sales.orders o on o.id = oi.order_id
WHERE o.status <> 'Cancelled' AND o.order_date BETWEEN '2025-01-01' AND '2025-03-31'
GROUP BY cat."name"
HAVING SUM(oi.subtotal - COALESCE(oi.discount_amount,0)) >= 10000

INTERSECT

SELECT
	cat."name" as category_name,
	0 as q1_sales,
	SUM(oi.subtotal - COALESCE(oi.discount_amount,0)) as q2_sales,
	0 as q3_sales,
	0 as q4_sales
FROM marketing.categories cat
JOIN inventory.products p ON cat.id = p.category_id
JOIN sales.order_items oi on oi.product_id = p.id
JOIN sales.orders o on o.id = oi.order_id
WHERE o.status <> 'Cancelled' AND o.order_date BETWEEN '2025-04-01' AND '2025-06-30'
GROUP BY cat."name"
HAVING SUM(oi.subtotal - COALESCE(oi.discount_amount,0)) >= 10000

INTERSECT

SELECT
	cat."name" as category_name,
	0 as q1_sales,
	0 as q2_sales,
	SUM(oi.subtotal - COALESCE(oi.discount_amount,0)) as q3_sales,
	0 as q4_sales
FROM marketing.categories cat
JOIN inventory.products p ON cat.id = p.category_id
JOIN sales.order_items oi on oi.product_id = p.id
JOIN sales.orders o on o.id = oi.order_id
WHERE o.status <> 'Cancelled' AND o.order_date BETWEEN '2025-07-01' AND '2025-09-30'
GROUP BY cat."name"
HAVING SUM(oi.subtotal - COALESCE(oi.discount_amount,0)) >= 10000

INTERSECT

SELECT
	cat."name" as category_name,
	0 as q1_sales,
	0 as q2_sales,
	0 as q3_sales,
	SUM(oi.subtotal - COALESCE(oi.discount_amount,0)) as q4_sales
FROM marketing.categories cat
JOIN inventory.products p ON cat.id = p.category_id
JOIN sales.order_items oi on oi.product_id = p.id
JOIN sales.orders o on o.id = oi.order_id
WHERE o.status <> 'Cancelled' AND o.order_date BETWEEN '2025-10-01' AND '2025-12-31'
GROUP BY cat."name"
HAVING SUM(oi.subtotal - COALESCE(oi.discount_amount,0)) >= 10000
;

WITH star_categories AS (
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
-- Solicitante: Director de Operaciones
-- Prioridad: Urgente
-- ----------------------------------------------------------------------------

-- Auditoría de logística urgente. El CFO detectó que hay productos activos
-- en el catálogo que tienen stock en ALGÚN almacén pero NO tienen stock en
-- el almacén más cercano a su proveedor (mismo país).
--
-- Más concretamente: necesito productos que cumplan estas DOS condiciones:
--   a) Tienen stock > 0 en al menos un warehouse (cualquier país).
--   b) NO tienen stock > 0 en NINGÚN warehouse que esté en el MISMO PAÍS
--      donde está registrado el proveedor del producto.
--
-- REQUISITOS:
-- - Mostrar: product_name, sku, supplier_name, supplier_country,
--   total_stock_global (suma de quantity en TODOS los warehouses),
--   stock_in_supplier_country (suma de quantity SOLO en warehouses del país
--   del proveedor; debe ser 0).
-- - Solo productos activos (is_active = TRUE).
-- - Ordenar por total_stock_global descendente (los más preocupantes primero).
--
-- PISTA: Necesitas encontrar el conjunto de productos con stock global > 0
-- y luego RESTAR (EXCEPT) aquellos que tienen stock en warehouses del país
-- de su proveedor. O puedes usar una combinación de EXISTS + NOT EXISTS.
--
-- RESTRICCIÓN: Debes usar EXCEPT en tu solución (puedes combinarlo con
-- otras técnicas si lo necesitas).

-- Escribe tu consulta aquí abajo:
SELECT
	p."name" as product_name,
	p.sku,
	s."name" as supplier_name,
	co."name" as supplier_country
FROM inventory.products p
JOIN core.suppliers s on s.id = p.supplier_id
JOIN core.cities ci on ci.id = s.city_id
JOIN core.countries co on co.id = ci.country_id
WHERE EXISTS(
SELECT 1 
FROM inventory.stocks st
WHERE st.product_id = p.id
and st.quantity>0)
AND NOT EXISTS (
	SELECT 1 
	FROM inventory.warehouses w 
	JOIN core.cities ciw on ciw.id = w.city_id
	JOIN inventory.stocks stw on stw.warehouse_id = w.id
	WHERE ciw.country_id = ci.country_id AND stw.quantity>0);

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
ORDER BY pgs.total_stock_global DESC
LIMIT 10;