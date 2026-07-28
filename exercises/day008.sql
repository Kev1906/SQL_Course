-- ============================================================================
-- SQL Master Course - Day 008 Exercises (DataMartX)
-- Topic: Date Functions (EXTRACT, DATE_TRUNC, INTERVAL, Time Zones)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Ejercicio 1 -- Ticket OPS-421: Análisis de velocidad de procesamiento de órdenes
-- Solicitante: COO (Chief Operating Officer)
-- Prioridad: Alta
-- ----------------------------------------------------------------------------

-- El COO necesita un reporte de eficiencia operativa del warehouse. Quiere
-- entender cuánto tiempo tarda cada orden desde que se crea hasta que se envía,
-- y detectar cuellos de botella por día de la semana y turno.
--
-- Necesito para cada orden entregada:
--   - ID de orden y fecha de creación
--   - Fecha de entrega
--   - Tiempo total de procesamiento (desde order_date hasta delivered_at)
--     en días y horas
--   - Día de la semana en que se creó la orden (nombre completo: Lunes, Martes, etc.)
--   - Turno en que se creó la orden:
--     - 'Matutino' si fue entre 6:00 y 13:59
--     - 'Vespertino' si fue entre 14:00 y 21:59
--     - 'Nocturno' si fue entre 22:00 y 5:59
--   - Si la orden se entregó el mismo día (fecha local, no timestamp), marcar
--     como 'SAME_DAY', sino 'NEXT_DAY_OR_LATER'
--   - Nombre del método de envío
--   - Ciudad de entrega
--
-- Luego, agregar por día de la semana y turno:
--   - Cantidad de órdenes
--   - Tiempo promedio de procesamiento en horas
--   - % de órdenes entregadas el mismo día
--   - Método de envío más usado en ese turno
--
-- REQUISITOS:
-- - Mostrar en el detalle: order_id, order_date, delivered_at, processing_days,
--   processing_hours, day_of_week, shift, delivery_speed_flag, shipping_method,
--   delivery_city
-- - Mostrar en el resumen: day_of_week, shift, order_count, avg_processing_hours,
--   same_day_pct, most_used_shipping
-- - Solo órdenes con status 'Delivered' y delivered_at NOT NULL
-- - Convertir timestamps a zona horaria 'America/Mexico_City' ANTES de extraer
--   componentes de fecha/hora
-- - Ordenar el detalle por processing_days DESC (las más lentas primero)
-- - Ordenar el resumen por day_of_week (Lunes=1, Domingo=0) y shift
-- - RESTRICCIÓN: Debes usar EXTRACT, DATE_TRUNC, INTERVAL, y AT TIME ZONE.
--   No uses funciones de string para parsear fechas.

-- Escribe tu consulta aquí abajo (detalle):

SELECT
	o.id as order_id,
	(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE as order_date,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE as delivered_date,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE - (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE as processing_days,
	EXTRACT(HOUR FROM (sh.delivery_date AT TIME ZONE 'America/Mexico_City')-(o.order_date AT TIME ZONE 'America/Mexico_City')) as processing_hours,
	CASE EXTRACT(DOW FROM (o.order_date AT TIME ZONE 'America/Mexico_City'))
		WHEN 0 THEN 'Domingo'
        WHEN 1 THEN 'Lunes'
        WHEN 2 THEN 'Martes'
        WHEN 3 THEN 'Miércoles'
        WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes'
        WHEN 6 THEN 'Sábado'
     END as day_of_week,
     CASE 
     	WHEN EXTRACT(HOUR FROM (o.order_date AT TIME ZONE 'America/Mexico_City')) BETWEEN 6 AND 13 THEN 'Matutino'
     	WHEN EXTRACT(HOUR FROM (o.order_date AT TIME ZONE 'America/Mexico_City')) BETWEEN 14 AND 21 THEN 'Vespertino'
     	ELSE 'Nocturno'
     END as shift,
     CASE
     	WHEN (sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE = (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE THEN 'SAME_DAY'
     	ELSE 'NEXT_DAY_OR_LATER'
     END as delivery_speed_flag,
     -- no hay shipment method en la base de datos
     ci."name" as delivery_city
FROM sales.orders o
JOIN logistics.shipments sh on sh.order_id = o.id
JOIN core.customers c ON c.id = o.customer_id
JOIN core.cities ci on ci.id = c.city_id
WHERE o.status = 'Delivered' AND sh.delivery_date is not NULL
ORDER BY processing_days DESC;

-- Escribe tu consulta aquí abajo (resumen agregado):

WITH delivery_detail as (
SELECT
	o.id as order_id,
	(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE as order_date,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE as delivered_date,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE - (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE as processing_days,
	EXTRACT(HOUR FROM (sh.delivery_date AT TIME ZONE 'America/Mexico_City')-(o.order_date AT TIME ZONE 'America/Mexico_City')) as processing_hours,
	CASE EXTRACT(DOW FROM (o.order_date AT TIME ZONE 'America/Mexico_City'))
		WHEN 0 THEN 'Domingo'
        WHEN 1 THEN 'Lunes'
        WHEN 2 THEN 'Martes'
        WHEN 3 THEN 'Miércoles'
        WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes'
        WHEN 6 THEN 'Sábado'
     END as day_of_week,
     CASE 
     	WHEN EXTRACT(HOUR FROM (o.order_date AT TIME ZONE 'America/Mexico_City')) BETWEEN 6 AND 13 THEN 'Matutino'
     	WHEN EXTRACT(HOUR FROM (o.order_date AT TIME ZONE 'America/Mexico_City')) BETWEEN 14 AND 21 THEN 'Vespertino'
     	ELSE 'Nocturno'
     END as shift,
     CASE
     	WHEN (sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE = (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE THEN 'SAME_DAY'
     	ELSE 'NEXT_DAY_OR_LATER'
     END as delivery_speed_flag,
     -- no hay shipment method en la base de datos
     ci."name" as delivery_city
FROM sales.orders o
JOIN logistics.shipments sh on sh.order_id = o.id
JOIN core.customers c ON c.id = o.customer_id
JOIN core.cities ci on ci.id = c.city_id
WHERE o.status = 'Delivered' AND sh.delivery_date is not NULL)
SELECT
	day_of_week,
	shift,
	COUNT(*) as order_count,
	round(AVG(processing_days * 24 + processing_hours),2) as avg_processing_hours,
	SUM(
	CASE
		WHEN delivery_speed_flag = 'SAME_DAY' THEN 1
		ELSE 0
	END) * 100 / COUNT(*) as same_day_pct
FROM delivery_detail
GROUP BY day_of_week, shift
ORDER BY (
CASE day_of_week
	WHEN 'Lunes'     THEN 0
    WHEN 'Martes'    THEN 1
    WHEN 'Miércoles' THEN 2
    WHEN 'Jueves'    THEN 3
    WHEN 'Viernes'   THEN 4
    WHEN 'Sábado'    THEN 5
    ELSE 6
END) ASC, shift;

-- ============================================================================
-- SOLUCIÓN PROFESIONAL -- Ejercicio 1 (Detalle)
-- ============================================================================
SELECT
	o.id AS order_id,
	(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE AS order_date,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE AS delivered_date,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE - (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE AS processing_days,
	ROUND(EXTRACT(EPOCH FROM (sh.delivery_date - o.order_date)) / 3600, 2) AS processing_hours,
	CASE EXTRACT(DOW FROM (o.order_date AT TIME ZONE 'America/Mexico_City'))
		WHEN 0 THEN 'Domingo'
		WHEN 1 THEN 'Lunes'
		WHEN 2 THEN 'Martes'
		WHEN 3 THEN 'Miércoles'
		WHEN 4 THEN 'Jueves'
		WHEN 5 THEN 'Viernes'
		WHEN 6 THEN 'Sábado'
	END AS day_of_week,
	CASE
		WHEN EXTRACT(HOUR FROM (o.order_date AT TIME ZONE 'America/Mexico_City')) BETWEEN 6 AND 13 THEN 'Matutino'
		WHEN EXTRACT(HOUR FROM (o.order_date AT TIME ZONE 'America/Mexico_City')) BETWEEN 14 AND 21 THEN 'Vespertino'
		ELSE 'Nocturno'
	END AS shift,
	CASE
		WHEN (sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE = (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE THEN 'SAME_DAY'
		ELSE 'NEXT_DAY_OR_LATER'
	END AS delivery_speed_flag,
	sp.name AS shipping_method,
	ci.name AS delivery_city
FROM sales.orders o
JOIN logistics.shipments sh ON sh.order_id = o.id
JOIN logistics.shippers sp ON sp.id = sh.shipper_id
JOIN core.customers c ON c.id = o.customer_id
JOIN core.cities ci ON ci.id = c.city_id
WHERE o.status = 'Delivered'
	AND sh.delivery_date IS NOT NULL
ORDER BY processing_days DESC;

-- ============================================================================
-- SOLUCIÓN PROFESIONAL -- Ejercicio 1 (Resumen)
-- ============================================================================
WITH delivery_detail AS (
	SELECT
		o.id AS order_id,
		(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE - (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE AS processing_days,
		EXTRACT(EPOCH FROM (sh.delivery_date - o.order_date)) / 3600 AS processing_hours,
		CASE EXTRACT(DOW FROM (o.order_date AT TIME ZONE 'America/Mexico_City'))
			WHEN 0 THEN 'Domingo'
			WHEN 1 THEN 'Lunes'
			WHEN 2 THEN 'Martes'
			WHEN 3 THEN 'Miércoles'
			WHEN 4 THEN 'Jueves'
			WHEN 5 THEN 'Viernes'
			WHEN 6 THEN 'Sábado'
		END AS day_of_week,
		EXTRACT(DOW FROM (o.order_date AT TIME ZONE 'America/Mexico_City')) AS dow_num,
		CASE
			WHEN EXTRACT(HOUR FROM (o.order_date AT TIME ZONE 'America/Mexico_City')) BETWEEN 6 AND 13 THEN 'Matutino'
			WHEN EXTRACT(HOUR FROM (o.order_date AT TIME ZONE 'America/Mexico_City')) BETWEEN 14 AND 21 THEN 'Vespertino'
			ELSE 'Nocturno'
		END AS shift,
		CASE
			WHEN (sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE = (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE THEN 'SAME_DAY'
			ELSE 'NEXT_DAY_OR_LATER'
		END AS delivery_speed_flag,
		sp.name AS shipping_method
	FROM sales.orders o
	JOIN logistics.shipments sh ON sh.order_id = o.id
	JOIN logistics.shippers sp ON sp.id = sh.shipper_id
	WHERE o.status = 'Delivered'
		AND sh.delivery_date IS NOT NULL
),
shipping_rank AS (
	SELECT
		day_of_week,
		dow_num,
		shift,
		shipping_method,
		COUNT(*) AS cnt,
		ROW_NUMBER() OVER (PARTITION BY day_of_week, shift ORDER BY COUNT(*) DESC) AS rn
	FROM delivery_detail
	GROUP BY day_of_week, dow_num, shift, shipping_method
)
SELECT
	dd.day_of_week,
	dd.shift,
	COUNT(*) AS order_count,
	ROUND(AVG(dd.processing_hours), 2) AS avg_processing_hours,
	ROUND(
		SUM(CASE WHEN dd.delivery_speed_flag = 'SAME_DAY' THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
		2
	) AS same_day_pct,
	MAX(CASE WHEN sr.rn = 1 THEN sr.shipping_method END) AS most_used_shipping
FROM delivery_detail dd
LEFT JOIN shipping_rank sr ON sr.day_of_week = dd.day_of_week AND sr.shift = dd.shift
GROUP BY dd.day_of_week, dd.dow_num, dd.shift
ORDER BY dd.dow_num, dd.shift;

-- ----------------------------------------------------------------------------
-- Ejercicio 2 -- Ticket MKT-567: Análisis de recencia y frecuencia para segmentación RFM
-- Solicitante: Director de Marketing
-- Prioridad: Crítica
-- ----------------------------------------------------------------------------

-- El Director de Marketing necesita segmentar clientes usando el modelo RFM
-- (Recency, Frequency, Monetary) para campañas personalizadas. Necesita
-- calcular métricas temporales precisas para cada cliente.
--
-- Necesito para CADA cliente que ha comprado al menos 1 vez:
--   - ID de cliente y nombre completo
--   - Fecha de primera compra (solo fecha, sin hora)
--   - Fecha de última compra (solo fecha, sin hora)
--   - Días desde la última compra hasta CURRENT_DATE (recencia)
--   - Clasificación de recencia:
--     - 'CHAMPION' si compró en los últimos 30 días
--     - 'LOYAL' si compró entre 31 y 90 días atrás
--     - 'AT_RISK' si compró entre 91 y 180 días atrás
--     - 'HIBERNATING' si compró entre 181 y 365 días atrás
--     - 'LOST' si han pasado más de 365 días
--   - Cantidad total de órdenes no canceladas (frecuencia)
--   - Clasificación de frecuencia:
--     - 'HIGH' si tiene 10+ órdenes
--     - 'MEDIUM' si tiene entre 4 y 9 órdenes
--     - 'LOW' si tiene entre 1 y 3 órdenes
--   - Revenue total (suma de net_amount de órdenes no canceladas) (monetary)
--   - Clasificación monetaria:
--     - 'PREMIUM' si revenue > $5,000
--     - 'STANDARD' si revenue entre $1,000 y $5,000
--     - 'BASIC' si revenue < $1,000
--   - Días entre primera y última compra (lifespan del cliente)
--   - Frecuencia de compra promedio: días entre órdenes (lifespan / (orders - 1))
--     Si solo tiene 1 orden, mostrar NULL
--   - Mes y año de última compra (formato: 'YYYY-MM')
--
-- REQUISITOS:
-- - Mostrar: customer_id, full_name, first_purchase_date, last_purchase_date,
--   recency_days, recency_segment, total_orders, frequency_segment,
--   total_revenue, monetary_segment, customer_lifespan_days,
--   avg_days_between_orders, last_purchase_month
-- - Solo clientes con al menos 1 orden no cancelada
-- - Ordenar por recency_days ASC (los más recientes primero)
-- - RESTRICCIÓN: Debes usar CURRENT_DATE, EXTRACT, y aritmética de fechas.
--   Convierte timestamps a zona horaria 'America/Mexico_City' antes de truncar.
--   No uses AGE() para calcular recencia (usa resta directa de fechas).

-- Escribe tu consulta aquí abajo:
WITH order_info as (
SELECT
	c.id as customer_id,
	c.first_name || ' ' || c.last_name as full_name,
	MIN(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE as first_purchase_date,
	MAX(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE as last_purchase_date,
	COUNT(DISTINCT(o.id)) as total_orders,
	SUM(COALESCE(o.net_amount,0)) as total_revenue
FROM sales.orders o 
JOIN core.customers c on o.customer_id = c.id
WHERE o.status <> 'Cancelled'
GROUP BY c.id,c.first_name,c.last_name)
SELECT
	customer_id,
	full_name,
	first_purchase_date,
	last_purchase_date,
	CURRENT_DATE - last_purchase_date as recency_days,
	CASE
		WHEN CURRENT_DATE - last_purchase_date <= 30 THEN 'CHAMPION'
		WHEN CURRENT_DATE - last_purchase_date <= 90 THEN 'LOYAL'
		WHEN CURRENT_DATE - last_purchase_date <= 180 THEN 'AT_RISK'
		WHEN CURRENT_DATE - last_purchase_date <= 365 THEN 'HIBERNATING'
		ELSE 'LOST'
	END as recency_segment,
	total_orders,
	CASE
		WHEN total_orders >= 10 THEN 'HIGH'
		WHEN total_orders >= 4 THEN 'MEDIUM'
		ELSE 'LOW'
	END as frequency_segment,
	total_revenue,
	CASE
		WHEN total_revenue > 5000 THEN 'PREMIUM'
		WHEN total_revenue >= 1000 THEN 'STANDARD'
		ELSE 'BASIC'
	END as monetary_segment,
	first_purchase_date - last_purchase_date as customer_lifespan_days,
	CASE
		WHEN total_orders =1 THEN NULL
		ELSE(last_purchase_date - first_purchase_date) / total_orders
	END as avg_days_between_orders,
	to_char(last_purchase_date, 'YYYY-MM') as last_purchase_month
FROM order_info
WHERE total_orders > 0
ORDER BY recency_days ASC;

-- ============================================================================
-- SOLUCIÓN PROFESIONAL -- Ejercicio 2
-- ============================================================================
WITH order_info AS (
	SELECT
		c.id AS customer_id,
		c.first_name || ' ' || c.last_name AS full_name,
		MIN(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE AS first_purchase_date,
		MAX(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE AS last_purchase_date,
		COUNT(DISTINCT o.id) AS total_orders,
		SUM(COALESCE(o.net_amount, 0)) AS total_revenue
	FROM sales.orders o
	JOIN core.customers c ON o.customer_id = c.id
	WHERE o.status <> 'Cancelled'
	GROUP BY c.id, c.first_name, c.last_name
)
SELECT
	customer_id,
	full_name,
	first_purchase_date,
	last_purchase_date,
	CURRENT_DATE - last_purchase_date AS recency_days,
	CASE
		WHEN CURRENT_DATE - last_purchase_date <= 30 THEN 'CHAMPION'
		WHEN CURRENT_DATE - last_purchase_date <= 90 THEN 'LOYAL'
		WHEN CURRENT_DATE - last_purchase_date <= 180 THEN 'AT_RISK'
		WHEN CURRENT_DATE - last_purchase_date <= 365 THEN 'HIBERNATING'
		ELSE 'LOST'
	END AS recency_segment,
	total_orders,
	CASE
		WHEN total_orders >= 10 THEN 'HIGH'
		WHEN total_orders >= 4 THEN 'MEDIUM'
		ELSE 'LOW'
	END AS frequency_segment,
	total_revenue,
	CASE
		WHEN total_revenue > 5000 THEN 'PREMIUM'
		WHEN total_revenue >= 1000 THEN 'STANDARD'
		ELSE 'BASIC'
	END AS monetary_segment,
	last_purchase_date - first_purchase_date AS customer_lifespan_days,
	CASE
		WHEN total_orders = 1 THEN NULL
		ELSE (last_purchase_date - first_purchase_date) / NULLIF(total_orders - 1, 0)
	END AS avg_days_between_orders,
	TO_CHAR(last_purchase_date, 'YYYY-MM') AS last_purchase_month
FROM order_info
ORDER BY recency_days ASC;

-- ----------------------------------------------------------------------------
-- Ejercicio 3 -- Ticket FIN-789: Cierre contable mensual y análisis de cut-off
-- Solicitante: Controller Financiero
-- Prioridad: Crítica
-- ----------------------------------------------------------------------------

-- El Controller Financiero necesita validar el cierre contable mensual.
-- Hay un problema recurrente: órdenes creadas el último día del mes que se
-- entregan el mes siguiente, causando inconsistencias en reportes de revenue.
--
-- Necesito identificar órdenes "problemáticas" para el cierre contable:
--   - Órdenes creadas en los últimos 3 días de cualquier mes
--   - Y entregadas en el mes siguiente
--   - Estas órdenes causan que el revenue se reconozca en un mes diferente
--     al de la creación
--
-- Para cada orden problemática mostrar:
--   - ID de orden
--   - Fecha de creación (con hora, en zona horaria local)
--   - Fecha de entrega (con hora, en zona horaria local)
--   - Mes de creación (YYYY-MM)
--   - Mes de entrega (YYYY-MM)
--   - Días entre creación y entrega
--   - Net amount de la orden
--   - Nombre del cliente
--   - Método de envío
--   - Flag: 'CROSS_MONTH' si la creación y entrega son en meses diferentes
--
-- Luego, agregar por mes de creación:
--   - Cantidad de órdenes problemáticas
--   - Revenue total de órdenes problemáticas
--   - % que representa sobre el revenue total del mes
--   - Método de envío con más órdenes problemáticas
--   - Días promedio de retraso (entrega - creación)
--
-- REQUISITOS:
-- - Mostrar en el detalle: order_id, order_date_local, delivered_at_local,
--   creation_month, delivery_month, days_to_deliver, net_amount,
--   customer_name, shipping_method, cross_month_flag
-- - Mostrar en el resumen: creation_month, problematic_orders,
--   problematic_revenue, pct_of_monthly_revenue, top_shipping_method,
--   avg_delay_days
-- - Solo órdenes entregadas (status = 'Delivered', delivered_at NOT NULL)
-- - Convertir todos los timestamps a zona horaria 'America/Mexico_City'
-- - Para identificar "últimos 3 días del mes", usa:
--   DATE_TRUNC('month', order_date) + INTERVAL '1 month' - INTERVAL '3 days'
--   como límite inferior
-- - Ordenar el detalle por creation_month DESC, days_to_deliver DESC
-- - Ordenar el resumen por creation_month DESC
-- - RESTRICCIÓN: Debes usar DATE_TRUNC, INTERVAL, EXTRACT, y AT TIME ZONE.
--   No uses funciones de string para manipular fechas.

-- Escribe tu consulta aquí abajo (detalle):
SELECT
	o.id as order_id,
	(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE as order_date_local,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE as delivered_at_local,
	to_char(o.order_date AT TIME ZONE 'America/Mexico_City', 'YYYY-MM') as creation_month,
	to_char(sh.delivery_date AT TIME ZONE 'America/Mexico_City', 'YYYY-MM') as delivery_month,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE - (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE as days_to_deliver,
	o.net_amount,
	c.first_name as customer_name,
	-- no hay metodo de envio,
	CASE
		WHEN EXTRACT(MONTH FROM (o.order_date AT TIME ZONE 'America/Mexico_City')) <> EXTRACT(MONTH FROM (sh.delivery_date AT TIME ZONE 'America/Mexico_City')) THEN 'CROSS_MONTH'
		ELSE NULL
	END as cross_month_flag
FROM sales.orders o 
JOIN logistics.shipments sh on o.id = sh.order_id
JOIN core.customers c on c.id = o.customer_id
WHERE o.status = 'Delivered' AND sh.delivery_date is not NULL AND o.order_date BETWEEN DATE_TRUNC('month',o.order_date) + INTERVAL '1 month' - INTERVAL '3 days' AND DATE_TRUNC('month',o.order_date) + INTERVAL '1 month'
ORDER BY creation_month DESC, days_to_deliver DESC;

-- Escribe tu consulta aquí abajo (resumen agregado):

WITH orders_detail as (
SELECT
	o.id as order_id,
	(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE as order_date_local,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE as delivered_at_local,
	to_char(o.order_date AT TIME ZONE 'America/Mexico_City', 'YYYY-MM') as creation_month,
	to_char(sh.delivery_date AT TIME ZONE 'America/Mexico_City', 'YYYY-MM') as delivery_month,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE - (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE as days_to_deliver,
	o.net_amount,
	c.first_name as customer_name,
	-- no hay metodo de envio,
	CASE
		WHEN EXTRACT(MONTH FROM (o.order_date AT TIME ZONE 'America/Mexico_City')) <> EXTRACT(MONTH FROM (sh.delivery_date AT TIME ZONE 'America/Mexico_City')) THEN 'CROSS_MONTH'
		ELSE NULL
	END as cross_month_flag
FROM sales.orders o 
JOIN logistics.shipments sh on o.id = sh.order_id
JOIN core.customers c on c.id = o.customer_id
WHERE o.status = 'Delivered' AND sh.delivery_date is not NULL AND o.order_date BETWEEN DATE_TRUNC('month',o.order_date) + INTERVAL '1 month' - INTERVAL '3 days' AND DATE_TRUNC('month',o.order_date) + INTERVAL '1 month')
SELECT
	od.creation_month,
	SUM(
	CASE
		WHEN od.cross_month_flag = 'CROSS_MONTH' THEN 1
		ELSE 0
	END) as problematic_orders,
	SUM(od.net_amount) as problematic_revenue,
	round(SUM(od.net_amount)/max(io_table.total_revenue_month) *100,2) as pct_of_monthly_revenue,
	round(AVG(days_to_deliver),2) as avg_delay_days
FROM orders_detail od
JOIN (
SELECT
	to_char(io.order_date AT TIME ZONE 'America/Mexico_City', 'YYYY-MM') as cm,
	SUM(io.net_amount) as total_revenue_month
FROM sales.orders io
WHERE io.status = 'Delivered'
GROUP BY to_char(io.order_date AT TIME ZONE 'America/Mexico_City', 'YYYY-MM')) io_table on io_table.cm = od.creation_month
GROUP BY creation_month
ORDER BY creation_month;

-- ============================================================================
-- SOLUCIÓN PROFESIONAL -- Ejercicio 3 (Detalle)
-- ============================================================================
SELECT
	o.id AS order_id,
	(o.order_date AT TIME ZONE 'America/Mexico_City') AS order_date_local,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City') AS delivered_at_local,
	TO_CHAR(o.order_date AT TIME ZONE 'America/Mexico_City', 'YYYY-MM') AS creation_month,
	TO_CHAR(sh.delivery_date AT TIME ZONE 'America/Mexico_City', 'YYYY-MM') AS delivery_month,
	(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE - (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE AS days_to_deliver,
	o.net_amount,
	c.first_name || ' ' || c.last_name AS customer_name,
	sp.name AS shipping_method,
	'CROSS_MONTH' AS cross_month_flag
FROM sales.orders o
JOIN logistics.shipments sh ON o.id = sh.order_id
JOIN logistics.shippers sp ON sp.id = sh.shipper_id
JOIN core.customers c ON c.id = o.customer_id
WHERE o.status = 'Delivered'
	AND sh.delivery_date IS NOT NULL
	AND (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE >=
		DATE_TRUNC('month', o.order_date AT TIME ZONE 'America/Mexico_City') + INTERVAL '1 month' - INTERVAL '3 days'
	AND DATE_TRUNC('month', o.order_date AT TIME ZONE 'America/Mexico_City') <>
		DATE_TRUNC('month', sh.delivery_date AT TIME ZONE 'America/Mexico_City')
ORDER BY creation_month DESC, days_to_deliver DESC;

-- ============================================================================
-- SOLUCIÓN PROFESIONAL -- Ejercicio 3 (Resumen)
-- ============================================================================
WITH problematic_orders AS (
	SELECT
		o.id AS order_id,
		TO_CHAR(o.order_date AT TIME ZONE 'America/Mexico_City', 'YYYY-MM') AS creation_month,
		(sh.delivery_date AT TIME ZONE 'America/Mexico_City')::DATE - (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE AS days_to_deliver,
		o.net_amount,
		sp.name AS shipping_method
	FROM sales.orders o
	JOIN logistics.shipments sh ON o.id = sh.order_id
	JOIN logistics.shippers sp ON sp.id = sh.shipper_id
	WHERE o.status = 'Delivered'
		AND sh.delivery_date IS NOT NULL
		AND (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE >=
			DATE_TRUNC('month', o.order_date AT TIME ZONE 'America/Mexico_City') + INTERVAL '1 month' - INTERVAL '3 days'
		AND DATE_TRUNC('month', o.order_date AT TIME ZONE 'America/Mexico_City') <>
			DATE_TRUNC('month', sh.delivery_date AT TIME ZONE 'America/Mexico_City')
),
monthly_revenue AS (
	SELECT
		TO_CHAR(order_date AT TIME ZONE 'America/Mexico_City', 'YYYY-MM') AS month,
		SUM(net_amount) AS total_revenue
	FROM sales.orders
	WHERE status = 'Delivered'
	GROUP BY TO_CHAR(order_date AT TIME ZONE 'America/Mexico_City', 'YYYY-MM')
),
shipping_rank AS (
	SELECT
		creation_month,
		shipping_method,
		COUNT(*) AS cnt,
		ROW_NUMBER() OVER (PARTITION BY creation_month ORDER BY COUNT(*) DESC) AS rn
	FROM problematic_orders
	GROUP BY creation_month, shipping_method
)
SELECT
	po.creation_month,
	COUNT(*) AS problematic_orders,
	SUM(po.net_amount) AS problematic_revenue,
	ROUND(SUM(po.net_amount) * 100.0 / NULLIF(mr.total_revenue, 0), 2) AS pct_of_monthly_revenue,
	MAX(CASE WHEN sr.rn = 1 THEN sr.shipping_method END) AS top_shipping_method,
	ROUND(AVG(po.days_to_deliver), 2) AS avg_delay_days
FROM problematic_orders po
JOIN monthly_revenue mr ON mr.month = po.creation_month
LEFT JOIN shipping_rank sr ON sr.creation_month = po.creation_month
GROUP BY po.creation_month, mr.total_revenue
ORDER BY po.creation_month DESC;