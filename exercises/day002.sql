-- Ejercicio 1 -- Ticket COM-042: Clasificación de productos por margen
-- Solicitante: Director Comercial
-- Prioridad: Alta

-- Necesito un reporte de todos los productos activos con su margen de ganancia calculado como (price - cost) / price * 100. Clasifícalos en 3 categorías:
-- - "High Margin": margen >= 60%
-- - "Medium Margin": margen entre 30% y 59.99%
-- - "Low Margin": margen < 30%

-- Si el precio es 0 o NULL, clasifícalo como "Invalid Price".

-- Muestra: product_name, sku, price, cost, margin_percentage (2 decimales), margin_category.
-- Ordena por margen de mayor a menor.
SELECT
	product_name,
	sku,
	price,
	cost,
	margin_percentage,
	CASE
		WHEN margin_percentage <= 0 THEN 'Invalid Price'
		WHEN margin_percentage < 30 THEN 'Low Margin'
		WHEN margin_percentage < 60 THEN 'Medium Margin'
		ELSE 'High Margin'
	END AS margin_category
FROM (
	SELECT 
		p."name" as product_name,
		p.sku as sku,
		p.price as price,
		p."cost" as cost,
		CASE
			WHEN p.price is NULL THEN -1
			WHEN p.price = 0 THEN 0
			ELSE ROUND((p.price - COALESCE(p."cost",0))/p.price *100,2)
		END AS margin_percentage
	FROM inventory.products as p
	WHERE p.is_active = TRUE)
ORDER BY margin_percentage DESC;

SELECT
    p.name AS product_name,
    p.sku,
    p.price,
    p.cost,
    CASE
        WHEN p.price IS NULL OR p.price = 0 THEN NULL
        ELSE ROUND((p.price - COALESCE(p.cost, 0)) / p.price * 100, 2)
    END AS margin_percentage,
    CASE
        WHEN p.price IS NULL OR p.price = 0 THEN 'Invalid Price'
        WHEN ROUND((p.price - COALESCE(p.cost, 0)) / p.price * 100, 2) >= 60 THEN 'High Margin'
        WHEN ROUND((p.price - COALESCE(p.cost, 0)) / p.price * 100, 2) >= 30 THEN 'Medium Margin'
        ELSE 'Low Margin'
    END AS margin_category
FROM inventory.products p
WHERE p.is_active = TRUE
ORDER BY margin_percentage DESC NULLS LAST;
    

-- Ejercicio 2 -- Ticket FIN-018: Estado de cuenta de clientes
-- Solicitante: Equipo de Finanzas
-- Prioridad: Alta

-- Encontramos discrepancias en el reporte mensual. Necesitamos un listado de TODOS los clientes activos (incluso los que nunca compraron) con:
-- - Nombre completo
-- - Email
-- - Cantidad total de órdenes (excluyendo canceladas)
-- - Total gastado (net_amount)
-- - Su última fecha de compra
-- - Una clasificación:
--   - "VIP": más de $10,000 gastados
--   - "Regular": entre $1,000 y $9,999
--   - "Occasional": entre $1 y $999
--   - "Inactive": 0 gastado o sin compras

-- Asegúrate de que los clientes sin compras muestren 0 en vez de NULL en los campos numéricos y "Never" en la fecha.
-- Ordena por total gastado descendente.
SELECT
	customer_id,
	nombre_completo,
	cantidad_total_ordenes,
	total_gastado,
	ultima_compra,
	CASE
		WHEN total_gastado >= 10000 THEN 'VIP'
		WHEN total_gastado >= 1000 THEN 'Regular'
		WHEN total_gastado >= 1 THEN 'Occasional'
		ELSE 'Inactive'
	END as clasificacion
FROM (SELECT
	c.id as customer_id,
	COALESCE(c.first_name,'')||' '||COALESCE(c.last_name,'') as nombre_completo,
	c.email as email,
	COUNT(DISTINCT(o.id)) as cantidad_total_ordenes,
	SUM(COALESCE(o.net_amount,0)) as total_gastado,
	MAX(o.order_date)::DATE as ultima_compra
FROM core.customers c 
LEFT JOIN sales.orders o ON c.id = o.customer_id
AND o.status <> 'Cancelled'
GROUP BY c.id, c.first_name,c.last_name, email)
ORDER BY total_gastado DESC;

SELECT
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    COUNT(DISTINCT o.id) AS total_orders,
    COALESCE(SUM(o.net_amount), 0) AS total_spent,
    COALESCE(MAX(o.order_date)::TEXT, 'Never') AS last_purchase,
    CASE
        WHEN COALESCE(SUM(o.net_amount), 0) >= 10000 THEN 'VIP'
        WHEN COALESCE(SUM(o.net_amount), 0) >= 1000  THEN 'Regular'
        WHEN COALESCE(SUM(o.net_amount), 0) >= 1     THEN 'Occasional'
        ELSE 'Inactive'
    END AS customer_tier
FROM core.customers c
LEFT JOIN sales.orders o
    ON c.id = o.customer_id
    AND o.status <> 'Cancelled'
WHERE c.is_active = TRUE
GROUP BY c.id, c.first_name, c.last_name, c.email
ORDER BY total_spent DESC;


-- Ejercicio 3 -- Ticket OPS-055: Semáforo de inventario
-- Solicitante: Director de Operaciones
-- Prioridad: Urgente

-- El warehouse manager no tiene visibilidad del estado del inventario. Necesito un "semáforo" para cada producto en cada almacén:
-- - "CRITICAL": quantity = 0
-- - "LOW": quantity > 0 AND quantity <= reorder_level
-- - "OK": quantity > reorder_level

-- Además, calcula el valor total del stock (quantity * price) y clasifícalo por valor:
-- - "High Value": valor > $50,000
-- - "Medium Value": valor entre $10,000 y $50,000
-- - "Low Value": valor < $10,000

-- Muestra: warehouse_name, product_name, sku, quantity, reorder_level, stock_status, stock_value, value_category.
-- Ordena: CRITICAL primero, luego LOW, luego OK. Dentro de cada grupo, mayor valor primero.
SELECT
	warehouse_id,
	warehouse_name,
	product_name,
	sku,
	quantity,
	reorder_level,
	CASE
	 	WHEN quantity = 0 THEN 'CRITICAL'
	 	WHEN quantity <= reorder_level THEN 'LOW'
	 	ELSE 'OK'
	END AS stock_status,
	stock_value,
	CASE
	 	WHEN stock_value > 50000 THEN 'High Value'
	 	WHEN stock_value >= 10000 THEN 'Medium Value'
	 	ELSE 'Low Value'
	END AS stock_status
FROM (SELECT
	w.id as warehouse_id,
	w."name" as warehouse_name,
	p."name" as product_name,
	p.sku as sku,
	COALESCE(s.quantity,0) as quantity,
	s.reorder_level as reorder_level,
	(COALESCE(s.quantity,0) * COALESCE(p.price,0)) as stock_value
FROM inventory.warehouses w 
	JOIN inventory.stocks s ON w.id = s.warehouse_id
	JOIN inventory.products p ON p.id = s.product_id);

SELECT
    w.name AS warehouse_name,
    p.name AS product_name,
    p.sku,
    s.quantity,
    s.reorder_level,
    CASE
        WHEN s.quantity = 0 THEN 'CRITICAL'
        WHEN s.quantity <= s.reorder_level THEN 'LOW'
        ELSE 'OK'
    END AS stock_status,
    (s.quantity * p.price) AS stock_value,
    CASE
        WHEN (s.quantity * p.price) > 50000 THEN 'High Value'
        WHEN (s.quantity * p.price) >= 10000 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS value_category
FROM inventory.warehouses w
INNER JOIN inventory.stocks s ON w.id = s.warehouse_id
INNER JOIN inventory.products p ON p.id = s.product_id
ORDER BY
    CASE
        WHEN s.quantity = 0 THEN 1
        WHEN s.quantity <= s.reorder_level THEN 2
        ELSE 3
    END,
    (s.quantity * p.price) DESC;