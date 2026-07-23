-- ============================================================================
-- SQL Master Course - Day 006 Exercises (DataMartX)
-- Topic: Window Functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Ejercicio 1 -- Ticket HR-055: Salary benchmarking por departamento
-- Solicitante: VP de Recursos Humanos
-- Prioridad: Alta
-- ----------------------------------------------------------------------------

-- El VP de RRHH necesita un reporte de salary benchmarking para la revisión
-- anual de compensaciones. Necesito ver cómo se compara el salario de cada
-- empleado contra los promedios de su departamento y de toda la empresa.
--
-- Necesito:
--   - Cada empleado activo (is_active = TRUE) con su departamento, job_title,
--     y salario actual
--   - Promedio de salario de SU departamento
--   - Promedio de salario de TODA la empresa
--   - Diferencia vs promedio de departamento (en $ y en %)
--   - Ranking del empleado dentro de su departamento por salario (1 = mejor pagado)
--   - Percentil del empleado dentro de su departamento (usar NTILE(4) para
--     dividir en cuartiles: Q1 = bottom 25%, Q4 = top 25%)
--
-- REQUISITOS:
-- - Mostrar: department_name, employee_id, full_name, job_title, salary,
--   dept_avg_salary, company_avg_salary, diff_vs_dept_avg ($),
--   diff_vs_dept_pct (%), dept_rank, salary_quartile
-- - Solo empleados activos
-- - Ordenar por department_name ASC, luego dept_rank ASC
-- - RESTRICCIÓN: Debes usar al menos 4 window functions diferentes.
--   No uses subconsultas correlacionadas ni self-joins.

-- Escribe tu consulta aquí abajo:
WITH salary_info as (
SELECT
	d."name" as department_name,
	e.id as employee_id,
	e.first_name || ' ' || e.last_name as full_name,
	e.job_title,
	e.salary,
	AVG(e.salary) OVER (PARTITION by d.id) as dept_avg_salary,
	AVG(e.salary) OVER() as company_avg_salary,
	DENSE_RANK() OVER (PARTITION BY d.id ORDER BY e.salary DESC) AS dept_rank,
	NTILE(4) OVER(PARTITION BY d.id ORDER BY e.salary DESC) as salary_quartile
FROM hr.departments d
LEFT JOIN hr.employees e on d.id = e.department_id AND e.is_active = TRUE)
SELECT
	department_name,
	employee_id,
	full_name,
	job_title,
	salary,
	round(dept_avg_salary,2) as dept_avg_salary,
	round(company_avg_salary,2) as company_avg_salary,
	round(salary - dept_avg_salary,2) as "diff_vs_dep_avg ($)",
	round((salary - dept_avg_salary)/dept_avg_salary*100,2) as "diff_vs_dep_avg (%)",
	dept_rank,
	salary_quartile
FROM salary_info
ORDER BY department_name ASC, dept_rank asc;

-- SOLUCIÓN PROFESIONAL:
WITH salary_base AS (
    SELECT 
        d.name AS department_name,
        e.id AS employee_id,
        e.first_name || ' ' || e.last_name AS full_name,
        e.job_title,
        e.salary,
        AVG(e.salary) OVER (PARTITION BY d.id) AS dept_avg_salary,
        AVG(e.salary) OVER () AS company_avg_salary,
        DENSE_RANK() OVER (PARTITION BY d.id ORDER BY e.salary DESC) AS dept_rank,
        NTILE(4) OVER (PARTITION BY d.id ORDER BY e.salary DESC) AS salary_quartile
    FROM hr.departments d
    JOIN hr.employees e ON d.id = e.department_id
    WHERE e.is_active = TRUE
)
SELECT 
    department_name,
    employee_id,
    full_name,
    job_title,
    salary,
    ROUND(dept_avg_salary, 2) AS dept_avg_salary,
    ROUND(company_avg_salary, 2) AS company_avg_salary,
    ROUND(salary - dept_avg_salary, 2) AS diff_vs_dept_avg_dollar,
    ROUND((salary - dept_avg_salary) * 100.0 / NULLIF(dept_avg_salary, 0), 2) AS diff_vs_dept_avg_pct,
    dept_rank,
    salary_quartile
FROM salary_base
ORDER BY department_name ASC, dept_rank ASC;

-- ----------------------------------------------------------------------------
-- Ejercicio 2 -- Ticket ANL-178: Análisis de frecuencia de compra con detección de churn
-- Solicitante: Director de CRM
-- Prioridad: Urgente
-- ----------------------------------------------------------------------------

-- El director de CRM quiere identificar clientes en riesgo de churn basándose
-- en la frecuencia de sus compras. Necesita ver el patrón de compra de cada
-- cliente y detectar anomalías.
--
-- Necesito:
--   - Para cada cliente que haya hecho al menos 2 compras no canceladas en 2025:
--     mostrar cada compra con la fecha, monto, y días transcurridos desde
--     la compra anterior
--   - Promedio de días entre compras del cliente (avg_days_between)
--   - Desviación de la última compra vs su promedio personal
--     (si la última compra fue hace más días de lo normal, es señal de churn)
--   - Flag de riesgo: 'HIGH RISK' si los días desde la última compra superan
--     2x su promedio personal, 'MEDIUM RISK' si superan 1.5x, 'OK' si no
--
-- REQUISITOS:
-- - Mostrar: customer_id, full_name, total_orders, first_order_date,
--   last_order_date, avg_days_between, days_since_last_order,
--   risk_flag
-- - Solo clientes con al menos 2 órdenes no canceladas en 2025
-- - days_since_last_order = días desde la última compra hasta CURRENT_DATE
-- - Ordenar por risk_flag (HIGH RISK primero), luego days_since_last_order DESC
-- - RESTRICCIÓN: Debes usar LAG() para calcular días entre compras y
--   window functions para las agregaciones por cliente.
--   No uses subconsultas correlacionadas.

-- Escribe tu consulta aquí abajo:

WITH customer_orders_2025 as (
SELECT
	 c.id as customer_id,
	 c.first_name || ' ' || c.last_name as full_name,
	 COUNT(o.id) OVER(PARTITION BY c.id) as total_orders,
	 o.order_date,
	 LAG(o.order_date) OVER (PARTITION BY c.id ORDER BY o.order_date) AS prev_order_date 
FROM core.customers c
JOIN sales.orders o on c.id = o.customer_id AND o.status <> 'Cancelled' AND EXTRACT(YEAR FROM o.order_date) = '2025'), customer_agg as (
SELECT
	customer_id,
	full_name,
	total_orders,
	MIN(order_date)::DATE as first_order_date,
	MAX(order_date)::DATE as last_order_date,
	round(AVG(order_date::DATE-prev_order_date::DATE),1) as avg_days_between,
	CURRENT_DATE::DATE - MAX(order_date)::DATE as days_since_last_order
	
FROM customer_orders_2025
WHERE total_orders >= 2 AND prev_order_date IS NOT NULL
GROUP BY customer_id,full_name,total_orders)
SELECT
	customer_agg.*,
	CASE
		WHEN days_since_last_order > 2 * avg_days_between THEN 'HIGH RISK'
		WHEN days_since_last_order > 1.5 * avg_days_between THEN 'MEDIUM RISK'
		ELSE 'OK'
	END as risk_flag
FROM customer_agg
ORDER BY days_since_last_order DESC;

-- SOLUCIÓN PROFESIONAL:
WITH customer_orders_detail AS (
    SELECT 
        c.id AS customer_id,
        c.first_name || ' ' || c.last_name AS full_name,
        o.id AS order_id,
        o.order_date,
        o.net_amount,
        LAG(o.order_date) OVER (PARTITION BY c.id ORDER BY o.order_date) AS prev_order_date,
        (o.order_date::DATE - LAG(o.order_date::DATE) OVER (PARTITION BY c.id ORDER BY o.order_date)) AS days_between_orders,
        COUNT(*) OVER (PARTITION BY c.id) AS total_orders,
        MIN(o.order_date) OVER (PARTITION BY c.id) AS first_order_date,
        MAX(o.order_date) OVER (PARTITION BY c.id) AS last_order_date
    FROM core.customers c
    JOIN sales.orders o ON o.customer_id = c.id
    WHERE o.status <> 'Cancelled'
        AND o.order_date >= '2025-01-01'
        AND o.order_date < '2026-01-01'
),
customer_summary AS (
    SELECT DISTINCT
        customer_id,
        full_name,
        total_orders,
        first_order_date::DATE,
        last_order_date::DATE,
        AVG(days_between_orders) OVER (PARTITION BY customer_id) AS avg_days_between,
        (CURRENT_DATE - last_order_date::DATE) AS days_since_last_order
    FROM customer_orders_detail
    WHERE total_orders >= 2
)
SELECT 
    customer_id,
    full_name,
    total_orders,
    first_order_date,
    last_order_date,
    ROUND(avg_days_between, 1) AS avg_days_between,
    days_since_last_order,
    CASE 
        WHEN days_since_last_order > 2 * avg_days_between THEN 'HIGH RISK'
        WHEN days_since_last_order > 1.5 * avg_days_between THEN 'MEDIUM RISK'
        ELSE 'OK'
    END AS risk_flag
FROM customer_summary
ORDER BY 
    CASE 
        WHEN days_since_last_order > 2 * avg_days_between THEN 1
        WHEN days_since_last_order > 1.5 * avg_days_between THEN 2
        ELSE 3
    END,
    days_since_last_order DESC;

-- ----------------------------------------------------------------------------
-- Ejercicio 3 -- Ticket OPS-210: Scorecard de warehouses con tendencias y rankings
-- Solicitante: COO (Chief Operating Officer)
-- Prioridad: Crítica
-- ----------------------------------------------------------------------------

-- El COO necesita un scorecard mensual de cada warehouse para la reunión
-- ejecutiva. Quiere ver no solo los números actuales, sino también tendencias
-- y rankings competitivos entre warehouses.
--
-- Necesito por warehouse y mes:
--   - Revenue del mes (net_amount de órdenes no canceladas)
--   - Cantidad de órdenes del mes
--   - Revenue del mes anterior del MISMO warehouse (usar LAG)
--   - Variación % vs mes anterior (MoM growth)
--   - Revenue acumulado del año (running total desde enero)
--   - Ranking del warehouse por revenue del mes (1 = mejor)
--   - Ranking del warehouse por revenue acumulado del año
--   - Promedio de revenue del warehouse en los últimos 3 meses (media móvil)
--   - Porcentaje del revenue total de la empresa que representa este warehouse
--     en este mes
--
-- REQUISITOS:
-- - Mostrar: warehouse_name, order_month (YYYY-MM), monthly_revenue,
--   order_count, prev_month_revenue, mom_growth_pct, ytd_revenue,
--   monthly_rank, ytd_rank, moving_avg_3m, pct_of_total
-- - Solo meses de 2025
-- - Solo warehouses con al menos 1 orden en el mes
-- - Ordenar por order_month ASC, luego monthly_rank ASC
-- - RESTRICCIÓN: Debes usar al menos 6 window functions diferentes.
--   Combina PARTITION BY warehouse, PARTITION BY month, y window sin
--   partición (toda la tabla). No uses self-joins ni subconsultas
--   correlacionadas.

-- Escribe tu consulta aquí abajo:
WITH warehouse_monthly_revenue as (
SELECT
	w."name" as warehouse_name,
	to_char(o.order_date,'YYYY-MM') as order_month,
	COUNT(DISTINCT o.id) as order_count,
	SUM(oi.quantity*oi.unit_price - COALESCE(oi.discount_amount,0)) as monthly_revenue
FROM inventory.warehouses w
JOIN inventory.stocks st ON st.warehouse_id = w.id
JOIN sales.order_items oi ON oi.product_id = st.product_id
JOIN sales.orders o ON o.id = oi.order_id and o.status <> 'Cancelled' AND EXTRACT(YEAR FROM o.order_date) = '2025'
GROUP BY w.id, w."name", to_char(o.order_date,'YYYY-MM')), warehose_agg as(
SELECT
	warehouse_name,
	order_month,
	monthly_revenue,
	order_count,
	LAG(monthly_revenue) OVER(PARTITION BY warehouse_name ORDER BY order_month) as prev_month_revenue,
	SUM(monthly_revenue) OVER(PARTITION BY warehouse_name ORDER BY order_month) AS ytd_revenue,
	DENSE_RANK() OVER(PARTITION BY warehouse_name ORDER BY monthly_revenue DESC) as monthly_rank,
	AVG(monthly_revenue) OVER(PARTITION BY warehouse_name ORDER BY order_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) as moving_avg_3m,
	SUM(monthly_revenue) OVER(PARTITION BY order_month) as company_revenue,
	SUM(monthly_revenue) OVER(PARTITION BY order_month,warehouse_name) as warehouse_revenue
FROM warehouse_monthly_revenue
WHERE order_count >= 1)
SELECT
	warehouse_name,
	order_month,
	monthly_revenue,
	order_count,
	prev_month_revenue,
	CASE
		WHEN prev_month_revenue is NULL THEN NULL
		WHEN prev_month_revenue = 0 THEN 0 
		ELSE round((monthly_revenue-prev_month_revenue)/prev_month_revenue*100,2)
	END as mom_growth_pct,
	ytd_revenue,
	monthly_rank,
	DENSE_RANK() OVER(PARTITION BY warehouse_name ORDER BY ytd_revenue DESC) as ytd_rank,
	round(moving_avg_3m,2) as moving_avg_3m,
	round(warehouse_revenue/company_revenue * 100, 2) as pct_of_total
FROM warehose_agg
ORDER BY order_month ASC, monthly_rank ASC;

-- SOLUCIÓN PROFESIONAL:
WITH warehouse_monthly_base AS (
    SELECT 
        w.id AS warehouse_id,
        w.name AS warehouse_name,
        TO_CHAR(o.order_date, 'YYYY-MM') AS order_month,
        SUM(o.net_amount) AS monthly_revenue,
        COUNT(DISTINCT o.id) AS order_count
    FROM sales.orders o
    JOIN inventory.warehouses w ON w.id = o.warehouse_id
    WHERE o.status <> 'Cancelled'
        AND o.order_date >= '2025-01-01'
        AND o.order_date < '2026-01-01'
    GROUP BY w.id, w.name, TO_CHAR(o.order_date, 'YYYY-MM')
),
warehouse_metrics AS (
    SELECT 
        warehouse_id,
        warehouse_name,
        order_month,
        monthly_revenue,
        order_count,
        LAG(monthly_revenue) OVER (PARTITION BY warehouse_id ORDER BY order_month) AS prev_month_revenue,
        SUM(monthly_revenue) OVER (PARTITION BY warehouse_id ORDER BY order_month) AS ytd_revenue,
        DENSE_RANK() OVER (PARTITION BY order_month ORDER BY monthly_revenue DESC) AS monthly_rank,
        DENSE_RANK() OVER (PARTITION BY order_month ORDER BY SUM(monthly_revenue) OVER (PARTITION BY warehouse_id ORDER BY order_month) DESC) AS ytd_rank,
        AVG(monthly_revenue) OVER (
            PARTITION BY warehouse_id 
            ORDER BY order_month 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg_3m,
        SUM(monthly_revenue) OVER (PARTITION BY order_month) AS company_monthly_revenue
    FROM warehouse_monthly_base
    WHERE order_count >= 1
)
SELECT 
    warehouse_name,
    order_month,
    monthly_revenue,
    order_count,
    prev_month_revenue,
    ROUND((monthly_revenue - prev_month_revenue) * 100.0 / NULLIF(prev_month_revenue, 0), 2) AS mom_growth_pct,
    ytd_revenue,
    monthly_rank,
    ytd_rank,
    ROUND(moving_avg_3m, 2) AS moving_avg_3m,
    ROUND(monthly_revenue * 100.0 / NULLIF(company_monthly_revenue, 0), 2) AS pct_of_total
FROM warehouse_metrics
ORDER BY order_month ASC, monthly_rank ASC;