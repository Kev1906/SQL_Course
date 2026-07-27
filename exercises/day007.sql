-- ============================================================================
-- SQL Master Course - Day 007 Exercises (DataMartX)
-- Topic: Subqueries (Non-correlated, Correlated, Derived Tables, Scalar)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Ejercicio 1 -- Ticket SLS-312: Productos huérfanos -- activos pero nunca vendidos
-- Solicitante: Director de Inventarios
-- Prioridad: Alta
-- ----------------------------------------------------------------------------

-- El director de inventarios ha detectado que hay productos activos en el
-- catálogo que NUNCA han aparecido en una orden de venta. Necesita un reporte
-- completo para decidir si hacer markdown, liquidación, o darlos de baja.
--
-- Necesito:
--   - Todos los productos activos (is_active = TRUE) que NUNCA han aparecido
--     en sales.order_items (sin importar el status de la orden)
--   - Para cada producto mostrar:
--     - Nombre del producto y SKU
--     - Precio actual y costo
--     - Margen teórico (price - cost) y margen en %
--     - Nombre de su categoría
--     - Nombre de su proveedor
--     - Stock total actual (suma de quantity en todos los warehouses)
--     - Días desde que el producto fue creado hasta CURRENT_DATE
--
-- REQUISITOS:
-- - Mostrar: product_name, sku, price, cost, margin_dollar, margin_pct,
--   category_name, supplier_name, total_stock, days_since_listing
-- - Solo productos activos que NUNCA han aparecido en order_items
-- - Ordenar por days_since_listing DESC (los más antiguos primero,
--   prioridad para liquidación)
-- - RESTRICCIÓN: Debes usar NOT EXISTS para identificar los productos
--   sin ventas. NO uses NOT IN (riesgo de NULLs). NO uses LEFT JOIN + IS NULL.
-- - Debes usar al menos 2 JOINs adicionales para obtener categoría y proveedor.

-- Escribe tu consulta aquí abajo:
SELECT
	p."name" as product_name,
	p.sku,
	p.price,
	p."cost",
	COALESCE(p.price,0) - COALESCE(p."cost",0) as margin_dollar,
	(COALESCE(p.price,0) - COALESCE(p."cost",0))/NULLIF(p."cost",0) as margin_pct,
	cat."name" as category_name,
	sup."name" as supplier_name,
	st.quantity as total_stock,
	(CURRENT_DATE::DATE - p.created_at::DATE) as days_since_listing
FROM inventory.products p
JOIN (
	SELECT 
		product_id,
		SUM(quantity) as quantity
	FROM inventory.stocks
	GROUP BY product_id
	) st ON p.id = st.product_id
JOIN marketing.categories cat ON cat.id = p.category_id
JOIN core.suppliers sup ON sup.id = p.supplier_id
WHERE p.is_active = TRUE AND NOT EXISTS(
	SELECT 1 
	FROM sales.order_items oi 
	WHERE oi.product_id = p.id);

-- ============================================================================
-- SOLUCIÓN PROFESIONAL -- Ejercicio 1
-- ============================================================================
SELECT
	p."name" AS product_name,
	p.sku,
	p.price,
	p."cost",
	(p.price - p."cost") AS margin_dollar,
	ROUND((p.price - p."cost") * 100.0 / NULLIF(p."cost", 0), 2) AS margin_pct,
	cat."name" AS category_name,
	sup."name" AS supplier_name,
	COALESCE(st.total_stock, 0) AS total_stock,
	(CURRENT_DATE - p.created_at::DATE) AS days_since_listing
FROM inventory.products p
JOIN marketing.categories cat ON cat.id = p.category_id
JOIN core.suppliers sup ON sup.id = p.supplier_id
LEFT JOIN (
	SELECT product_id, SUM(quantity) AS total_stock
	FROM inventory.stocks
	GROUP BY product_id
) st ON st.product_id = p.id
WHERE p.is_active = TRUE
	AND NOT EXISTS (
		SELECT 1
		FROM sales.order_items oi
		WHERE oi.product_id = p.id
	)
ORDER BY days_since_listing DESC;

-- ----------------------------------------------------------------------------
-- Ejercicio 2 -- Ticket FIN-156: Reporte de equidad salarial con benchmarking
-- Solicitante: CHRO (Chief Human Resources Officer)
-- Prioridad: Crítica
-- ----------------------------------------------------------------------------

-- El CHRO necesita un análisis de equidad salarial para la junta directiva.
-- Necesita ver cómo se compara el salario de cada empleado activo contra
-- múltiples benchmarks de referencia.
--
-- Necesito para CADA empleado activo:
--   - Nombre completo, departamento, job_title, salario
--   - Promedio de salario de SU departamento (subquery correlacionada)
--   - Promedio de salario de TODA la empresa (subquery scalar)
--   - Salario máximo de SU departamento (subquery correlacionada)
--   - Diferencia en $ vs promedio de departamento
--   - Diferencia en % vs promedio de departamento
--   - Flag de equidad:
--     - 'UNDERPAID' si gana menos del 80% del promedio de su departamento
--     - 'FAIR' si gana entre 80% y 120% del promedio de su departamento
--     - 'OVERPAID' si gana más del 120% del promedio de su departamento
--   - Cantidad de empleados en su departamento (subquery correlacionada)
--   - Ranking del empleado dentro de su departamento por salario
--     (usar subquery correlacionada: contar cuántos ganan más que él + 1)
--
-- REQUISITOS:
-- - Mostrar: department_name, employee_id, full_name, job_title, salary,
--   dept_avg_salary, company_avg_salary, dept_max_salary,
--   diff_vs_dept_avg_dollar, diff_vs_dept_avg_pct, equity_flag,
--   dept_headcount, salary_rank_in_dept
-- - Solo empleados activos
-- - Ordenar por department_name ASC, luego salary DESC
-- - RESTRICCIÓN: Debes usar al menos 4 subqueries correlacionadas en el SELECT.
--   NO uses window functions para este ejercicio (ya las usamos el día 6,
--   ahora quiero que domines subqueries correlacionadas).
--   SÍ puedes usar una derived table en FROM si la necesitas para el
--   promedio de la empresa.

-- Escribe tu consulta aquí abajo:
WITH employee_info AS (
SELECT
	dp."name" as department_name,
	em.id as employee_id,
	em.first_name || ' ' || em.last_name as full_name,
	em.job_title,
	em.salary,
	(SELECT
		ROUND(AVG(salary),2) as dept_avg_salary
	FROM hr.employees emdept
	WHERE emdept.department_id = em.department_id),
	(SELECT
		ROUND(AVG(salary),2)
	FROM hr.employees) as company_avg_salary,
	(SELECT
		MAX(salary) as dept_max_salary
	FROM hr.employees emax
	WHERE emax.department_id = em.department_id),
	(SELECT
		COUNT(emcount.id) as dept_headcount
	FROM hr.employees emcount
	WHERE emcount.department_id = em.department_id),
	(SELECT
		COUNT(emrank.id)+1 as salary_rank_in_dept
	FROM hr.employees emrank
	WHERE emrank.department_id = em.department_id AND emrank.salary > em.salary)
FROM hr.employees em
JOIN hr.departments dp ON em.department_id = dp.id
)
SELECT
	department_name,
	employee_id,
	full_name,
	job_title,
	salary,
	dept_avg_salary,
	company_avg_salary,
	dept_max_salary,
	salary - dept_avg_salary as diff_vs_dept_avg_dollar,
	round((salary - dept_avg_salary)*100/NULLIF(dept_avg_salary,0)) as diff_vs_dept_avg_pct,
	CASE
		WHEN salary < 0.8*dept_avg_salary THEN 'UNDERPAID'
		WHEN salary BETWEEN 0.8*dept_avg_salary AND 1.2*dept_avg_salary THEN 'FAIR'
		ELSE 'OVERPAID'
	END as equity_flag,
	dept_headcount,
	salary_rank_in_dept
FROM employee_info
ORDER BY department_name ASC, salary DESC;

-- ============================================================================
-- SOLUCIÓN PROFESIONAL -- Ejercicio 2
-- ============================================================================
SELECT
	dp."name" AS department_name,
	em.id AS employee_id,
	em.first_name || ' ' || em.last_name AS full_name,
	em.job_title,
	em.salary,
	(SELECT ROUND(AVG(e2.salary), 2)
	 FROM hr.employees e2
	 WHERE e2.department_id = em.department_id AND e2.is_active = TRUE
	) AS dept_avg_salary,
	(SELECT ROUND(AVG(e3.salary), 2)
	 FROM hr.employees e3
	 WHERE e3.is_active = TRUE
	) AS company_avg_salary,
	(SELECT MAX(e4.salary)
	 FROM hr.employees e4
	 WHERE e4.department_id = em.department_id AND e4.is_active = TRUE
	) AS dept_max_salary,
	ROUND(em.salary - (
		SELECT AVG(e5.salary)
		FROM hr.employees e5
		WHERE e5.department_id = em.department_id AND e5.is_active = TRUE
	), 2) AS diff_vs_dept_avg_dollar,
	ROUND(
		(em.salary - (
			SELECT AVG(e6.salary)
			FROM hr.employees e6
			WHERE e6.department_id = em.department_id AND e6.is_active = TRUE
		)) * 100.0 / NULLIF((
			SELECT AVG(e7.salary)
			FROM hr.employees e7
			WHERE e7.department_id = em.department_id AND e7.is_active = TRUE
		), 0), 2
	) AS diff_vs_dept_avg_pct,
	CASE
		WHEN em.salary < 0.8 * (
			SELECT AVG(e8.salary)
			FROM hr.employees e8
			WHERE e8.department_id = em.department_id AND e8.is_active = TRUE
		) THEN 'UNDERPAID'
		WHEN em.salary <= 1.2 * (
			SELECT AVG(e9.salary)
			FROM hr.employees e9
			WHERE e9.department_id = em.department_id AND e9.is_active = TRUE
		) THEN 'FAIR'
		ELSE 'OVERPAID'
	END AS equity_flag,
	(SELECT COUNT(*)
	 FROM hr.employees e10
	 WHERE e10.department_id = em.department_id AND e10.is_active = TRUE
	) AS dept_headcount,
	(SELECT COUNT(*) + 1
	 FROM hr.employees e11
	 WHERE e11.department_id = em.department_id
	   AND e11.salary > em.salary
	   AND e11.is_active = TRUE
	) AS salary_rank_in_dept
FROM hr.employees em
JOIN hr.departments dp ON dp.id = em.department_id
WHERE em.is_active = TRUE
ORDER BY department_name ASC, em.salary DESC;

-- ----------------------------------------------------------------------------
-- Ejercicio 3 -- Ticket ANL-245: Análisis de clientes "full-spectrum" y su valor
-- Solicitante: VP de Analytics
-- Prioridad: Alta
-- ----------------------------------------------------------------------------

-- El VP de Analytics quiere identificar a los clientes "full-spectrum":
-- aquellos que han comprado productos de TODAS las subcategorías del catálogo
-- (una subcategoría es una categoría con parent_id NOT NULL).
--
-- Además, para cada cliente full-spectrum, necesita ver métricas avanzadas
-- calculadas con subqueries.
--
-- Necesito:
--   - Identificar clientes que han comprado al menos 1 producto de CADA
--     subcategoría existente (categorías con parent_id NOT NULL)
--   - Para cada cliente full-spectrum mostrar:
--     - Nombre completo y email
--     - Segmento del cliente
--     - Ciudad y país del cliente
--     - Total de órdenes no canceladas
--     - Revenue total (suma de net_amount de órdenes no canceladas)
--     - Ticket promedio
--     - Fecha de primera compra
--     - Fecha de última compra
--     - Cantidad de subcategorías diferentes compradas (debe ser igual al
--       total de subcategorías existentes)
--     - Nombre de la categoría de la que más ha comprado (en revenue)
--       (usar subquery scalar con LIMIT 1)
--     - Cantidad de productos diferentes que ha comprado
--       (usar subquery correlacionada o derived table)
--
-- REQUISITOS:
-- - Mostrar: customer_id, full_name, email, segment, city_name, country_name,
--   total_orders, total_revenue, avg_ticket, first_purchase_date,
--   last_purchase_date, subcategories_count, top_category_by_revenue,
--   distinct_products_count
-- - Solo clientes que han comprado en TODAS las subcategorías
-- - Ordenar por total_revenue DESC
-- - RESTRICCIÓN: Debes usar al menos:
--   - 1 subquery scalar en HAVING (para contar subcategorías totales)
--   - 1 derived table en FROM (para agregar métricas del cliente)
--   - 1 subquery scalar en SELECT (para top categoría por revenue)
--   - 1 JOIN para obtener ciudad y país
--   No uses window functions.

-- Escribe tu consulta aquí abajo:
SELECT
	c.id as customer_id,
	c.first_name || ' ' || c.last_name as full_name,
	c.email,
	c.segment,
	ci."name" as city_name,
	co."name" as country_name,
	customer_metrics.total_orders,
	customer_metrics.total_revenue,
	customer_metrics.avg_ticket,
	customer_metrics.first_purchase_date::DATE,
	customer_metrics.last_purchase_date::DATE,
	customer_metrics.subcategories_count,
	customer_metrics.distict_product_count
FROM core.customers c
JOIN core.cities ci ON ci.id = c.city_id
JOIN core.countries co ON co.id = ci.country_id
JOIN (
SELECT
	o.customer_id,
	COUNT(DISTINCT o.id) as total_orders,
	SUM(oi.subtotal - COALESCE(oi.discount_amount,0)) as total_revenue,
	round(SUM(oi.subtotal - COALESCE(oi.discount_amount,0))/COUNT(DISTINCT o.id),2) as avg_ticket,
	MIN(o.order_date) as first_purchase_date,
	MAX(o.order_date) as last_purchase_date,
	COUNT(DISTINCT cat.id) as subcategories_count,
	COUNT(DISTINCT p.id) as distict_product_count
FROM sales.orders o
JOIN sales.order_items oi on o.id = oi.order_id
JOIN inventory.products p on p.id = oi.product_id
JOIN marketing.categories cat on p.category_id = cat.id
WHERE cat.parent_id IS NOT NULL AND o.status <> 'Cancelled'
GROUP BY o.customer_id
HAVING COUNT(DISTINCT cat.id) = (
    SELECT COUNT(DISTINCT mcat.id)
    FROM marketing.categories mcat
    WHERE mcat.parent_id IS NOT NULL
)) customer_metrics on customer_metrics.customer_id = c.id;

-- ============================================================================
-- SOLUCIÓN PROFESIONAL -- Ejercicio 3
-- ============================================================================
WITH full_spectrum AS (
	SELECT o.customer_id
	FROM sales.orders o
	JOIN sales.order_items oi ON oi.order_id = o.id
	JOIN inventory.products p ON p.id = oi.product_id
	JOIN marketing.categories cat ON cat.id = p.category_id
	WHERE o.status <> 'Cancelled'
		AND cat.parent_id IS NOT NULL
	GROUP BY o.customer_id
	HAVING COUNT(DISTINCT cat.id) = (
		SELECT COUNT(*)
		FROM marketing.categories
		WHERE parent_id IS NOT NULL
	)
),
customer_metrics AS (
	SELECT
		o.customer_id,
		COUNT(DISTINCT o.id) AS total_orders,
		SUM(o.net_amount) AS total_revenue,
		ROUND(SUM(o.net_amount) / COUNT(DISTINCT o.id), 2) AS avg_ticket,
		MIN(o.order_date)::DATE AS first_purchase_date,
		MAX(o.order_date)::DATE AS last_purchase_date,
		(SELECT cat2.name
		 FROM sales.orders o2
		 JOIN sales.order_items oi2 ON oi2.order_id = o2.id
		 JOIN inventory.products p2 ON p2.id = oi2.product_id
		 JOIN marketing.categories cat2 ON cat2.id = p2.category_id
		 WHERE o2.customer_id = o.customer_id
		   AND o2.status <> 'Cancelled'
		 GROUP BY cat2.name
		 ORDER BY SUM(oi2.subtotal) DESC
		 LIMIT 1
		) AS top_category_by_revenue,
		COUNT(DISTINCT oi.product_id) AS distinct_products_count,
		(SELECT COUNT(DISTINCT cat3.id)
		 FROM sales.orders o3
		 JOIN sales.order_items oi3 ON oi3.order_id = o3.id
		 JOIN inventory.products p3 ON p3.id = oi3.product_id
		 JOIN marketing.categories cat3 ON cat3.id = p3.category_id
		 WHERE o3.customer_id = o.customer_id
		   AND o3.status <> 'Cancelled'
		   AND cat3.parent_id IS NOT NULL
		) AS subcategories_count
	FROM sales.orders o
	JOIN sales.order_items oi ON oi.order_id = o.id
	WHERE o.status <> 'Cancelled'
		AND o.customer_id IN (SELECT customer_id FROM full_spectrum)
	GROUP BY o.customer_id
)
SELECT
	c.id AS customer_id,
	c.first_name || ' ' || c.last_name AS full_name,
	c.email,
	c.segment,
	ci."name" AS city_name,
	co."name" AS country_name,
	cm.total_orders,
	cm.total_revenue,
	cm.avg_ticket,
	cm.first_purchase_date,
	cm.last_purchase_date,
	cm.subcategories_count,
	cm.top_category_by_revenue,
	cm.distinct_products_count
FROM core.customers c
JOIN core.cities ci ON ci.id = c.city_id
JOIN core.countries co ON co.id = ci.country_id
JOIN customer_metrics cm ON cm.customer_id = c.id
ORDER BY cm.total_revenue DESC;