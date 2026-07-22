-- ============================================================================
-- SQL Master Course - Day 005 Exercises (DataMartX)
-- Topic: Common Table Expressions (CTE)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Ejercicio 1 -- Ticket ANL-201: Reporte de conversión por segmento de cliente
-- Solicitante: VP de Marketing
-- Prioridad: Alta
-- ----------------------------------------------------------------------------

-- El director de marketing necesita un reporte que muestre, por cada segmento
-- de cliente (segment):
--   - Cantidad total de clientes activos en ese segmento
--   - Cantidad de esos clientes que han hecho AL MENOS una compra (orden no cancelada)
--   - Tasa de conversión (compradores / total clientes, en porcentaje con 2 decimales)
--   - Ticket promedio de los compradores (total gastado / cantidad de compradores)
--   - Revenue total del segmento
--
-- REQUISITOS:
-- - Mostrar: segment, total_customers, buyers, conversion_rate_pct, avg_ticket, total_revenue
-- - Solo clientes activos (is_active = TRUE)
-- - Ordenar por total_revenue descendente
-- - RESTRICCIÓN: Debes usar al menos 2 CTEs encadenados. No uses subconsultas en el SELECT.

-- Escribe tu consulta aquí abajo:

WITH segment_aggegation AS (SELECT
	c.segment,
    COUNT(DISTINCT c.id) as total_customers,
	COUNT(DISTINCT CASE
		WHEN o.status <>'Cancelled' THEN c.id
		ELSE NULL
	END) as buyers,
    SUM(COALESCE(o.total_amount,0)) as total_revenue
FROM core.customers c
LEFT JOIN sales.orders o on c.id = o.customer_id
WHERE c.is_active = TRUE
GROUP by c.segment)
SELECT
	sa.segment,
	sa.total_customers,
	sa.buyers,
	round(sa.buyers::NUMERIC/sa.total_customers,2) as conversion_rate_pct,
	round(sa.total_revenue/sa.buyers,2) as avg_ticket,
	sa.total_revenue
FROM segment_aggegation sa
ORDER BY sa.total_revenue DESC;

WITH active_customers AS (
    SELECT
        c.id,
        c.segment
    FROM core.customers c
    WHERE c.is_active = TRUE
),
buyer_stats AS (
    SELECT
        ac.segment,
        COUNT(DISTINCT ac.id) AS total_customers,
        COUNT(DISTINCT CASE WHEN o.id IS NOT NULL THEN ac.id END) AS buyers,
        COALESCE(SUM(o.net_amount), 0) AS total_revenue
    FROM active_customers ac
    LEFT JOIN sales.orders o
        ON o.customer_id = ac.id
        AND o.status <> 'Cancelled'
    GROUP BY ac.segment
)
SELECT
    segment,
    total_customers,
    buyers,
    ROUND(buyers::NUMERIC / NULLIF(total_customers, 0) * 100, 2) AS conversion_rate_pct,
    ROUND(total_revenue / NULLIF(buyers, 0), 2) AS avg_ticket,
    total_revenue
FROM buyer_stats
ORDER BY total_revenue DESC;
-- ----------------------------------------------------------------------------
-- Ejercicio 2 -- Ticket OPS-103: Top productos por almacén con contribución porcentual
-- Solicitante: Warehouse Manager
-- Prioridad: Alta
-- ----------------------------------------------------------------------------

-- Cada warehouse manager quiere saber qué productos son los más importantes
-- en SU almacén. Necesito:
--   - Para cada almacén, los top 5 productos por cantidad vendida
--     (suma de quantity en order_items para órdenes entregadas)
--   - Mostrar qué porcentaje representa ese producto sobre el total de
--     unidades vendidas en ese almacén
--
-- REQUISITOS:
-- - Mostrar: warehouse_name, product_name, sku, units_sold,
--   warehouse_total_units, pct_contribution (2 decimales)
-- - Solo órdenes con status 'Delivered'
-- - Solo los top 5 productos por almacén
-- - Ordenar por warehouse_name, luego por units_sold descendente
-- - RESTRICCIÓN: Debes usar al menos 2 CTEs. El primero debe calcular las
--   ventas por producto-almacén, el segundo debe agregar el ranking.

-- Escribe tu consulta aquí abajo:
WITH warehouse_units AS (SELECT
    w.name as warehouse_name,
    sum(oi.quantity) as warehouse_total_units
FROM inventory.warehouses w 
JOIN inventory.stocks st ON w.id = st.warehouse_id
JOIN inventory.products p on p.id = st.product_id
JOIN sales.order_items oi on oi.product_id = p.id
JOIN sales.orders o on o.id = oi.order_id
WHERE o.status = 'Delivered'
GROUP BY w.name)
SELECT
	wu.warehouse_name, 
	p."name" AS product_name,
	p.sku,
	wu.warehouse_total_units,
	sum(oi.quantity) as units_sold,
	sum(oi.quantity)/wu.warehouse_total_units as pct_contribution
FROM warehouse_units wu;

WITH product_warehouse_sales AS (
    SELECT
        w.id   AS warehouse_id,
        w.name AS warehouse_name,
        p.name AS product_name,
        p.sku,
        SUM(oi.quantity) AS units_sold
    FROM sales.order_items oi
    JOIN sales.orders o        ON o.id = oi.order_id
    JOIN inventory.products p  ON p.id = oi.product_id
    JOIN inventory.warehouses w ON w.id = o.warehouse_id
    WHERE o.status = 'Delivered'
    GROUP BY w.id, w.name, p.name, p.sku
),
ranked AS (
    SELECT
        pws.*,
        SUM(pws.units_sold) OVER (PARTITION BY pws.warehouse_id) AS warehouse_total_units,
        ROW_NUMBER() OVER (PARTITION BY pws.warehouse_id ORDER BY pws.units_sold DESC) AS rn,
        ROUND(pws.units_sold::NUMERIC / SUM(pws.units_sold) OVER (PARTITION BY pws.warehouse_id) * 100, 2) AS pct_contribution
    FROM product_warehouse_sales pws
)
SELECT
    warehouse_name,
    product_name,
    sku,
    units_sold,
    warehouse_total_units,
    pct_contribution
FROM ranked
WHERE rn <= 5
ORDER BY warehouse_name, units_sold DESC;
-- ----------------------------------------------------------------------------
-- Ejercicio 3 -- Ticket FIN-090: Resumen financiero mensual con comparativa vs mes anterior
-- Solicitante: CFO
-- Prioridad: Urgente
-- ----------------------------------------------------------------------------

-- El CFO necesita ver la evolución mensual de las finanzas con comparativa
-- contra el mes previo. Necesito:
--   - Revenue total por mes (net_amount de órdenes no canceladas)
--   - Cantidad de órdenes por mes
--   - Ticket promedio por mes
--   - Revenue del mes anterior
--   - Variación porcentual vs mes anterior (0.00 si es el primer mes)
--
-- REQUISITOS:
-- - Mostrar: order_month (formato 'YYYY-MM'), monthly_revenue, order_count,
--   avg_ticket, prev_month_revenue, mom_growth_pct
-- - Solo órdenes no canceladas del año 2025
-- - Ordenar por order_month ascendente
-- - RESTRICCIÓN: Debes usar un CTE para la agregación mensual y luego
--   window functions en el SELECT final para obtener el mes anterior.
--   No uses self-joins.

-- Escribe tu consulta aquí abajo:
WITH prev_month_revenue AS (
    SELECT
        to_char(po.order_date, 'YYYY-MM') as order_month,
        sum(po.total_amount) as prev_monthly_revenue
    FROM sales.orders po
    WHERE po.status = 'Delivered'
    GROUP by to_char(po.order_date, 'YYYY-MM')
)
    SELECT
        to_char(o.order_date, 'YYYY-MM') as order_month,
        sum(o.total_amount) as monthly_revenue,
        COUNT(DISTINCT o.id) as order_count,
        p.prev_monthly_revenue as prev_month_revenue,
        round(COALESCE((sum(o.total_amount)-p.prev_monthly_revenue)/p.prev_monthly_revenue*100,0),2) as mom_growth_pct
    FROM sales.orders o
    JOIN prev_month_revenue p on to_char(o.order_date - interval '1 month','YYYY-MM') = p.order_month
    WHERE o.status = 'Delivered'
    GROUP BY
    TO_CHAR(o.order_date, 'YYYY-MM'),
    p.prev_monthly_revenue
    ORDER by order_month ASC;

WITH monthly_financials AS (
    SELECT
        TO_CHAR(o.order_date, 'YYYY-MM') AS order_month,
        SUM(o.net_amount) AS monthly_revenue,
        COUNT(DISTINCT o.id) AS order_count,
        ROUND(SUM(o.net_amount) / NULLIF(COUNT(DISTINCT o.id), 0), 2) AS avg_ticket
    FROM sales.orders o
    WHERE o.status <> 'Cancelled'
        AND o.order_date >= '2025-01-01'
        AND o.order_date < '2026-01-01'
    GROUP BY TO_CHAR(o.order_date, 'YYYY-MM')
)
SELECT
    order_month,
    monthly_revenue,
    order_count,
    avg_ticket,
    LAG(monthly_revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
    COALESCE(
        ROUND((monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY order_month))
            / NULLIF(LAG(monthly_revenue) OVER (ORDER BY order_month), 0) * 100, 2),
        0.00
    ) AS mom_growth_pct
FROM monthly_financials
ORDER BY order_month ASC;

-- ----------------------------------------------------------------------------
-- Ejercicio 4 -- Ticket SLS-204: Análisis de cohortes por mes de primera compra
-- Solicitante: VP de Analytics
-- Prioridad: Alta
-- ----------------------------------------------------------------------------

-- El VP de Analytics quiere entender cómo se comporta el revenue por cohorte
-- de clientes. Una "cohorte" es el grupo de clientes que hicieron su PRIMERA
-- compra (cualquier orden no cancelada) en el mismo mes.
--
-- Necesito:
--   - Identificar la cohorte de cada cliente (mes de su primera orden no cancelada)
--   - Para cada cohorte, calcular cuántos clientes la componen
--   - Para cada cohorte, mostrar el revenue generado en cada "mes de vida"
--     (mes 0 = mes de la primera compra, mes 1 = siguiente mes, etc.)
--   - Solo considerar órdenes del año 2025 (tanto para definir cohortes como
--     para medir el revenue)
--
-- REQUISITOS:
-- - Mostrar: cohort_month (formato 'YYYY-MM'), cohort_size, months_since_cohort (entero),
--   revenue_month (formato 'YYYY-MM'), cohort_monthly_revenue, active_customers
--   (cuántos clientes de esa cohorte compraron en ese mes)
-- - Solo cohortes con al menos 5 clientes
-- - Ordenar por cohort_month ASC, luego months_since_cohort ASC
-- - RESTRICCIÓN: Debes usar al menos 3 CTEs encadenados.
--   CTE 1: primera compra por cliente. CTE 2: asignar cohorte y calcular
--   months_since_cohort. CTE 3: agregar revenue por cohorte-mes.
--   No uses subconsultas correlacionadas en el SELECT final.

-- Escribe tu consulta aquí abajo:
WITH first_customer_purchase AS (SELECT 
	c.id,
	c.is_active,
	o.id as order_id,
	MIN(o.order_date) as order_date
FROM core.customers c 
JOIN sales.orders o ON c.id = o.customer_id AND o.status <> 'Cancelled'
GROUP BY c.id, c.is_active, o.id), cohort_aggregation as (
	SELECT
		to_char(fcp.order_date, 'YYYY-MM') as cohort_month,
		COUNT(fcp.id) as cohort_size,
		EXTRACT(YEAR FROM age(CURRENT_DATE,fcp.order_date)) * 12 + EXTRACT(MONTH FROM age(CURRENT_DATE,fcp.order_date)) as months_since_cohort,
		sum(CASE 
			WHEN fcp.is_active THEN 1
			else 0
		END) as active_customers
	FROM first_customer_purchase fcp
	GROUP BY to_char(fcp.order_date, 'YYYY-MM'), EXTRACT(YEAR FROM age(CURRENT_DATE,fcp.order_date)) * 12 + EXTRACT(MONTH FROM age(CURRENT_DATE,fcp.order_date)) ), revenue_month as (
	SELECT
		ca.cohort_month,
		ca.cohort_size,
		ca.months_since_cohort,
		ca.active_customers,
		sum(COALESCE(so.net_amount,0)) as cohort_monthly_revenue
	FROM cohort_aggregation ca
	left JOIN sales.orders so ON to_char(so.order_date, 'YYYY-MM') =	 ca.cohort_month AND so.status <>'Cancelled' and ca.cohort_size>5
	GROUP BY ca.cohort_month,
		ca.cohort_size,
		ca.months_since_cohort,
		ca.active_customers)
	SELECT 
		rm.*
	FROM revenue_month rm
	ORDER BY rm.cohort_month ASC, rm.months_since_cohort ASC; 

-- SOLUCIÓN PROFESIONAL:
WITH first_purchase AS (
    SELECT 
        c.id AS customer_id,
        TO_CHAR(MIN(o.order_date), 'YYYY-MM') AS cohort_month
    FROM core.customers c
    JOIN sales.orders o ON o.customer_id = c.id
    WHERE o.status <> 'Cancelled'
        AND o.order_date >= '2025-01-01'
        AND o.order_date < '2026-01-01'
    GROUP BY c.id
),
cohort_size AS (
    SELECT 
        fp.cohort_month,
        COUNT(fp.customer_id) AS cohort_size
    FROM first_purchase fp
    GROUP BY fp.cohort_month
    HAVING COUNT(fp.customer_id) >= 5
),
cohort_revenue AS (
    SELECT 
        cs.cohort_month,
        cs.cohort_size,
        TO_CHAR(o.order_date, 'YYYY-MM') AS revenue_month,
        (EXTRACT(YEAR FROM o.order_date) * 12 + EXTRACT(MONTH FROM o.order_date))
            - (EXTRACT(YEAR FROM (cs.cohort_month || '-01')::DATE) * 12
               + EXTRACT(MONTH FROM (cs.cohort_month || '-01')::DATE))
            AS months_since_cohort,
        SUM(o.net_amount) AS cohort_monthly_revenue,
        COUNT(DISTINCT o.customer_id) AS active_customers
    FROM cohort_size cs
    JOIN first_purchase fp ON fp.cohort_month = cs.cohort_month
    JOIN sales.orders o ON o.customer_id = fp.customer_id
    WHERE o.status <> 'Cancelled'
        AND o.order_date >= '2025-01-01'
        AND o.order_date < '2026-01-01'
    GROUP BY cs.cohort_month, cs.cohort_size, TO_CHAR(o.order_date, 'YYYY-MM')
)
SELECT 
    cohort_month,
    cohort_size,
    months_since_cohort,
    revenue_month,
    cohort_monthly_revenue,
    active_customers
FROM cohort_revenue
ORDER BY cohort_month ASC, months_since_cohort ASC;

-- ----------------------------------------------------------------------------
-- Ejercicio 5 -- Ticket LOG-088: Scorecard de rendimiento por shipper con SLA
-- Solicitante: Director de Logística
-- Prioridad: Urgente
-- ----------------------------------------------------------------------------

-- El director de logística necesita evaluar el rendimiento de cada shipper.
-- Un shipment se considera "on-time" si delivery_date <= estimated_delivery.
--
-- Necesito un scorecard por shipper con:
--   - Total de shipments gestionados
--   - Shipments entregados (status = 'Delivered')
--   - Shipments on-time (entregados a tiempo sobre los estimados)
--   - On-time rate (% con 2 decimales; 0.00 si no tiene estimated_delivery)
--   - Promedio de días de entrega (delivery_date - shipment_date en días,
--     solo para shipments entregados)
--   - Revenue total asociado (net_amount de las órdenes vinculadas)
--   - Cantidad de devoluciones vinculadas a órdenes de ese shipper
--
-- REQUISITOS:
-- - Mostrar: shipper_name, total_shipments, delivered_shipments,
--   on_time_shipments, on_time_rate_pct, avg_delivery_days,
--   total_revenue, total_returns
-- - Ordenar por total_revenue descendente
-- - RESTRICCIÓN: Debes usar al menos 3 CTEs.
--   CTE 1: base de shipments con cálculo de días y flag on-time.
--   CTE 2: agregación por shipper de entregas y on-time.
--   CTE 3: devoluciones por shipper.
--   El SELECT final debe combinar los CTEs. No uses scalar subqueries en el SELECT.

-- Escribe tu consulta aquí abajo:
WITH shippers_cleaned as (
SELECT
	shippers.id as shipper_id,
	shippers."name" as shipper_name,
	sh.id as shipment_id,
	sh.status as shipment_status,
	CASE
		WHEN sh.delivery_date IS NULL THEN NULL
		ELSE EXTRACT(DAY FROM (sh.delivery_date - sh.shipment_date))
	END as delivered_days,
	CASE
		WHEN sh.delivery_date IS NULL THEN NULL
		WHEN sh.estimated_delivery IS NULL THEN NULL
		WHEN sh.delivery_date<=sh.estimated_delivery THEN 'on-time'
		ELSE 'out-time'
	END as on_time_flag
FROM logistics.shipments sh
left JOIN logistics.shippers ON sh.shipper_id = shippers.id),
shippers_agg as (
SELECT
	sc.shipper_id,
	sc.shipper_name,
	COUNT(sc.shipment_id) as total_shipments,
	SUM(CASE
			WHEN sc.shipment_status = 'Delivered' THEN 1
			ELSE 0
		END) as delivered_shipments,
	SUM(CASE
			WHEN sc.on_time_flag = 'on-time' THEN 1
			ELSE 0
		END) as on_time_shipments,
		AVG(sc.delivered_days) as avg_delivery_days
FROM shippers_cleaned as sc
GROUP BY sc.shipper_id,sc.shipper_name),
returns_revenue as (
SELECT
	sa.*,
	SUM(COALESCE(o.net_amount,0)) as total_revenue,
	SUM(CASE
			WHEN o.status = 'Returned' THEN COALESCE(o.net_amount,0)
			ELSE 0
		END) as total_returns
FROM sales.orders o
JOIN logistics.shipments osh ON osh.order_id = o.id 
JOIN shippers_agg sa ON sa.shipper_id = osh.shipper_id
GROUP by sa.shipper_id, sa.shipper_name, sa.total_shipments, sa.delivered_shipments, sa.on_time_shipments, sa.avg_delivery_days)
SELECT
	rr.shipper_name,
	rr.total_shipments,
	rr.delivered_shipments,
	rr.on_time_shipments,
	round(rr.avg_delivery_days,0) as avg_delivery_days,
	rr.total_revenue,
	rr.total_returns
FROM returns_revenue rr
ORDER BY rr.total_revenue DESC;

-- SOLUCIÓN PROFESIONAL:
WITH shipment_base AS (
    SELECT 
        sh.id AS shipment_id,
        sh.status AS shipment_status,
        sh.order_id,
        s.id AS shipper_id,
        s.name AS shipper_name,
        EXTRACT(DAY FROM sh.delivery_date - sh.shipment_date) AS delivery_days,
        CASE 
            WHEN sh.delivery_date IS NOT NULL 
                 AND sh.estimated_delivery IS NOT NULL 
                 AND sh.delivery_date::DATE <= sh.estimated_delivery 
            THEN 1 
            ELSE 0 
        END AS is_on_time
    FROM logistics.shipments sh
    JOIN logistics.shippers s ON s.id = sh.shipper_id
),
shipper_metrics AS (
    SELECT 
        shipper_id,
        shipper_name,
        COUNT(*) AS total_shipments,
        SUM(CASE WHEN shipment_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_shipments,
        SUM(is_on_time) AS on_time_shipments,
        ROUND(AVG(CASE WHEN shipment_status = 'Delivered' THEN delivery_days END)::NUMERIC, 2) AS avg_delivery_days
    FROM shipment_base
    GROUP BY shipper_id, shipper_name
),
returns_by_shipper AS (
    SELECT 
        sb.shipper_id,
        COUNT(DISTINCT r.id) AS total_returns
    FROM logistics.returns r
    JOIN sales.order_items oi ON oi.id = r.order_item_id
    JOIN sales.orders o ON o.id = oi.order_id
    JOIN logistics.shipments sb ON sb.order_id = o.id
    GROUP BY sb.shipper_id
),
revenue_by_shipper AS (
    SELECT 
        sb.shipper_id,
        SUM(o.net_amount) AS total_revenue
    FROM sales.orders o
    JOIN logistics.shipments sb ON sb.order_id = o.id
    GROUP BY sb.shipper_id
)
SELECT 
    sm.shipper_name,
    sm.total_shipments,
    sm.delivered_shipments,
    sm.on_time_shipments,
    ROUND(sm.on_time_shipments::NUMERIC / NULLIF(sm.delivered_shipments, 0) * 100, 2) AS on_time_rate_pct,
    COALESCE(sm.avg_delivery_days, 0.00) AS avg_delivery_days,
    COALESCE(rv.total_revenue, 0) AS total_revenue,
    COALESCE(rs.total_returns, 0) AS total_returns
FROM shipper_metrics sm
LEFT JOIN revenue_by_shipper rv ON rv.shipper_id = sm.shipper_id
LEFT JOIN returns_by_shipper rs ON rs.shipper_id = sm.shipper_id
ORDER BY COALESCE(rv.total_revenue, 0) DESC;