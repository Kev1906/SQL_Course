-- ============================================================================
-- SQL Master Course - Day 009 Exercises (DataMartX)
-- Topic: UPDATE y DELETE (DML profesional, transacciones, RETURNING)
-- ============================================================================
--
-- REGLAS DE SEGURIDAD PARA ESTOS EJERCICIOS (obligatorias):
--   1. TODO tu DML corre dentro de BEGIN; ... ROLLBACK; para NO alterar el
--      dataset del curso. El COMMIT solo se usa si el ticket lo pide.
--   2. Antes de cada UPDATE/DELETE, corre el SELECT equivalente (dry-run)
--      con el MISMO WHERE y anota cuántas filas esperas.
--   3. Usa RETURNING en cada UPDATE/DELETE y compara contra tu dry-run.
--   4. Después de cada DML, corre la validación post-cambio.
--
-- Entrega: para cada ticket entrega el script completo (dry-run, BEGIN,
-- DML con RETURNING, validación, ROLLBACK) como lo mandarías a code review.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Ejercicio 1 -- Ticket PAY-2301: Pagos zombie pendientes de hace 90+ días
-- Solicitante: Director de Finanzas
-- Prioridad: Alta
-- ----------------------------------------------------------------------------
--
-- El gateway de pagos tuvo un bug de reconciliación: existen pagos con
-- status 'Pending' que tienen más de 90 días de antigüedad. Finanzas ya
-- confirmó que esos pagos NUNCA se completaron (el gateway los rechazó en
-- silencio). La política contable exige marcarlos como 'Failed'.
--
-- REGLAS DE NEGOCIO:
--   - Solo pagos con status 'Pending' y payment_date anterior a
--     CURRENT_DATE - 90 días.
--   - SOLO si su orden asociada NO está en status 'Delivered' ni 'Shipped'
--     (una orden entregada o en camino con pago pendiente es otro problema
--     y va a un ticket aparte; no la toques).
--   - Actualizar sales.payments.status a 'Failed'.
--
-- ENTREGABLES (todo en un solo script transaccional):
--   a) Dry-run: lista de pagos afectados mostrando payment id, order_id,
--      payment_date, payment status, y status de la orden. Reporta el
--      COUNT total.
--   b) El UPDATE con RETURNING (id, order_id, status).
--   c) Validación post-cambio DENTRO de la transacción: cuántos pagos
--      'Pending' con 90+ días quedan asociados a órdenes no entregadas/
--      no enviadas (esperado: 0).
--   d) ROLLBACK al final (es práctica).
--
-- PREGUNTA DE NEGOCIO (responde en comentario SQL):
--   - ¿Tu UPDATE es idempotente? Si Finanzas lo corre dos veces por error,
--     ¿qué pasa la segunda vez? Justifica por qué.
--
-- RESTRICCIONES:
--   - Usa INTERVAL para el cálculo de 90 días (Día 8).
--   - Usa JOIN o EXISTS para la condición de la orden (Día 3).
--   - Prohibido usar subconsultas en el SET.

-- Escribe tu consulta aquí abajo:
BEGIN;

SELECT
	p.id as payment_id,
    o.id as order_id,
	(p.payment_date AT TIME ZONE 'America/Mexico_City')::DATE as payment_date,
    p.status as payment_status,
    o.status as order_status
FROM sales.payments p
JOIN sales.orders o on o.id = p.order_id
WHERE (p.payment_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '90 days'
	AND o.status NOT IN ('Delivered','Shipped')
	AND p.status = 'Pending';

UPDATE sales.payments p 
SET p.status = 'Failed'
FROM sales.orders o
WHERE o.id = p.order_id AND
    (p.payment_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '90 days'
	AND o.status NOT IN ('Delivered','Shipped')
	AND p.status = 'Pending'
RETURNING p.id, p.status;

SELECT COUNT(*) AS audit_rows
FROM audit.logs
WHERE table_name = 'sales.payments'
  AND action = 'UPDATE'
  AND logged_at >= CURRENT_DATE;

ROLLBACK;
--RESPUESTAS
-- La consulta o actualizacion es idempotente ya que solo afecta a las rows que cumplen esa condicion es decir si lo vuelvo a ejecutar no tiene un comportamiento no deseado. Ahora en su segunda ejecucion depende, si lo ejecutas el mismo dia esta ya no afecta a ninguna row pero si lo ejecutamos al dia siguiente o despues puede afectar a las rows buscadas

-- ============================================================================
-- SOLUCIÓN PROFESIONAL -- Ejercicio 1
-- ============================================================================
BEGIN;

-- Dry-run con COUNT
SELECT p.id AS payment_id, o.id AS order_id,
	p.payment_date, p.status AS payment_status, o.status AS order_status
FROM sales.payments p
JOIN sales.orders o ON o.id = p.order_id
WHERE p.payment_date < CURRENT_DATE - INTERVAL '90 days'
	AND o.status NOT IN ('Delivered', 'Shipped')
	AND p.status = 'Pending';

SELECT COUNT(*) AS total_to_update
FROM sales.payments p
JOIN sales.orders o ON o.id = p.order_id
WHERE p.payment_date < CURRENT_DATE - INTERVAL '90 days'
	AND o.status NOT IN ('Delivered', 'Shipped')
	AND p.status = 'Pending';

-- UPDATE (sin alias en SET)
UPDATE sales.payments
SET status = 'Failed'
FROM sales.orders o
WHERE o.id = payments.order_id
	AND payments.payment_date < CURRENT_DATE - INTERVAL '90 days'
	AND o.status NOT IN ('Delivered', 'Shipped')
	AND payments.status = 'Pending'
RETURNING payments.id, payments.order_id, payments.status;

-- Validación post-cambio
SELECT COUNT(*) AS still_pending
FROM sales.payments p
JOIN sales.orders o ON o.id = p.order_id
WHERE p.payment_date < CURRENT_DATE - INTERVAL '90 days'
	AND o.status NOT IN ('Delivered', 'Shipped')
	AND p.status = 'Pending';

ROLLBACK;

-- ----------------------------------------------------------------------------
-- Ejercicio 2 -- Ticket HR-884: Revisión salarial anual por desempeño
-- Solicitante: VP de People Operations
-- Prioridad: Media
-- ----------------------------------------------------------------------------
--
-- People aprobó el presupuesto de revisión salarial anual. Las reglas:
--
--   - Solo empleados ACTIVOS (is_active = TRUE) con al menos 1 año de
--     antigüedad (hire_date <= CURRENT_DATE - 1 año).
--   - Aumento por departamento:
--       * 'Engineering'  → +12%
--       * 'Sales'        → +8%
--       * resto de deptos → +5%
--   - TECHO SALARIAL: ningún empleado puede quedar con salario mayor a
--     $250,000. Si el aumento lo excede, su nuevo salario queda en $250,000.
--   - El salario NUNCA puede quedar por debajo del actual.
--
-- ENTREGABLES (todo en un solo script transaccional):
--   a) Dry-run: empleados candidatos mostrando id, nombre completo,
--      departamento, salario actual, % de aumento que le aplica, salario
--      nuevo calculado (ya con techo aplicado), y años de antigüedad.
--      Ordenado por departamento y salario nuevo DESC. Reporta el COUNT.
--   b) El UPDATE con RETURNING (id, salary).
--   c) Validación post-cambio DENTRO de la transacción:
--        - MAX(salary) de empleados activos (esperado: <= 250000)
--        - COUNT de empleados con salario <= 0 (esperado: 0)
--   d) Verificación de auditoría: cuántas filas UPDATE generó tu DML en
--      audit.logs para 'hr.employees' en el día de hoy.
--   e) ROLLBACK al final.
--
-- PREGUNTAS DE NEGOCIO (responde en comentario SQL):
--   - ¿Qué pasa con los empleados con menos de 1 año de antigüedad?
--     ¿Por qué tu WHERE los excluye de forma segura?
--   - ¿Por qué el techo conviene aplicarlo con LEAST() en el SET y no con
--     un segundo UPDATE posterior? (Piensa en atomicidad y en audit.logs.)
--
-- RESTRICCIONES:
--   - Un SOLO UPDATE. Prohibido un UPDATE por departamento.
--   - Usa CASE para el porcentaje y LEAST/GREATEST para el techo/piso.
--   - Usa INTERVAL para la antigüedad (Día 8).
--   - El nombre del departamento viene de hr.departments (join).

-- Escribe tu consulta aquí abajo:
BEGIN;

WITH candidates as (
SELECT
	e.id as employee_id,
	e.first_name || ' ' || e.last_name as full_name,
	dep."name" as department,
	e.salary as current_salary,
	CASE dep."name"
		WHEN 'Engineering' THEN 12
		WHEN 'Sales' THEN 8
		ELSE 5
	END::NUMERIC as increase_percentage,
	EXTRACT(YEAR FROM age(CURRENT_DATE,e.hire_date)) as service_years
FROM hr.employees e
JOIN hr.departments dep on dep.id = e.department_id
WHERE e.is_active = TRUE AND
	e.hire_date <= CURRENT_DATE - INTERVAL '1 year'), new_salaries as (
SELECT
	employee_id,
	full_name,
	department,
	current_salary,
	increase_percentage,
	round(CASE
		WHEN current_salary > 250000 THEN current_salary
		WHEN current_salary * (1 + (increase_percentage/100)) > 250000 THEN 250000
		ELSE current_salary * (1 + (increase_percentage/100))
	END,2) as new_salary,
	service_years
FROM candidates
ORDER BY department asc, new_salary desc )
UPDATE hr.employees hre
SET e.salary = 
FROM new_salaries nw
WHERE nw.employee_id = hre.id AND
	nw.new_salary <> hre.salary
RETURNING hre.id,hre.salary;

SELECT
	MAX(salary) as max_salary,
	SUM(CASE
			WHEN salary<=0 THEN 1
			ELSE 0
		END) as verify_count
FROM hr.employees
WHERE is_active = TRUE;

SELECT COUNT(*) AS audit_rows
FROM audit.logs
WHERE table_name = 'hr.employees'
  AND action = 'UPDATE'
  AND logged_at >= CURRENT_DATE;

ROLLBACK;
-- RESPUESTAS
-- 1. No son afectados ya que en el where se los excluye siguen teniendo el mismo sueldo 2.Porque la tabla resultante del CTE tiene ya el filtro puesto y al relacionarlos por los ids ese filtro se sigue aplicando 3.No use least hay error en mi consulta?

-- ============================================================================
-- SOLUCIÓN PROFESIONAL -- Ejercicio 2
-- ============================================================================
BEGIN;

-- Dry-run
WITH candidates AS (
	SELECT
		e.id AS employee_id,
		e.first_name || ' ' || e.last_name AS full_name,
		d.name AS department,
		e.salary AS current_salary,
		CASE d.name
			WHEN 'Engineering' THEN 12
			WHEN 'Sales' THEN 8
			ELSE 5
		END::NUMERIC AS increase_pct,
		EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.hire_date)) AS service_years
	FROM hr.employees e
	JOIN hr.departments d ON d.id = e.department_id
	WHERE e.is_active = TRUE
		AND e.hire_date <= CURRENT_DATE - INTERVAL '1 year'
)
SELECT
	employee_id, full_name, department, current_salary,
	increase_pct,
	GREATEST(LEAST(current_salary * (1 + increase_pct / 100), 250000), current_salary) AS new_salary,
	service_years
FROM candidates
ORDER BY department, new_salary DESC;

SELECT COUNT(*) AS total_candidates
FROM hr.employees e
JOIN hr.departments d ON d.id = e.department_id
WHERE e.is_active = TRUE
	AND e.hire_date <= CURRENT_DATE - INTERVAL '1 year';

-- UPDATE con LEAST/GREATEST en un solo SET
WITH candidates AS (
	SELECT
		e.id,
		GREATEST(
			LEAST(e.salary * (1 + CASE d.name
				WHEN 'Engineering' THEN 12
				WHEN 'Sales' THEN 8
				ELSE 5
			END::NUMERIC / 100), 250000),
			e.salary
		) AS new_salary
	FROM hr.employees e
	JOIN hr.departments d ON d.id = e.department_id
	WHERE e.is_active = TRUE
		AND e.hire_date <= CURRENT_DATE - INTERVAL '1 year'
)
UPDATE hr.employees
SET salary = c.new_salary
FROM candidates c
WHERE c.id = employees.id
	AND c.new_salary <> employees.salary
RETURNING employees.id, employees.salary;

-- Validaciones
SELECT MAX(salary) AS max_salary FROM hr.employees WHERE is_active = TRUE;
SELECT COUNT(*) AS invalid FROM hr.employees WHERE is_active = TRUE AND salary <= 0;

SELECT COUNT(*) AS audit_rows
FROM audit.logs
WHERE table_name = 'hr.employees'
	AND action = 'UPDATE'
	AND logged_at >= CURRENT_DATE;

ROLLBACK;

-- ----------------------------------------------------------------------------
-- Ejercicio 3 -- Ticket GOV-455: Purga de órdenes canceladas antiguas
-- Solicitante: Data Governance Office
-- Prioridad: Crítica (ventana de mantenimiento aprobada)
-- ----------------------------------------------------------------------------
--
-- Governance aprobó la purga física de órdenes CANCELLED cuya order_date
-- sea anterior a CURRENT_DATE - 3 años. Política de retención cumplida.
--
-- ANTES de aprobar el script, Governance exige un análisis de impacto:
-- estas órdenes tienen hijos. Revisa el schema y responde:
--   - sales.order_items.order_id → sales.orders con ON DELETE CASCADE
--   - sales.payments.order_id    → sales.orders con ON DELETE RESTRICT
--   - logistics.shipments.order_id → sales.orders con ON DELETE RESTRICT
--   - sales.invoices.order_id    → sales.orders con ON DELETE RESTRICT
--
-- FASE A -- Análisis de impacto (solo SELECTs):
--   a) ¿Cuántas órdenes 'Cancelled' con más de 3 años existen?
--   b) ¿Cuántos order_items se borrarían en cascada con ellas?
--   c) ¿Alguna de esas órdenes tiene payments, shipments o invoices?
--      (si existen, el DELETE fallará por RESTRICT: repórtalo)
--   d) Total de filas que se eliminarían entre orders + order_items.
--
-- FASE B -- Ejecución (transaccional):
--   e) DELETE de las órdenes que cumplen el criterio Y que NO tengan
--      payments, shipments ni invoices (las que bloquearían el RESTRICT
--      se quedan para un ticket de excepción). Usa NOT EXISTS (Día 3).
--      RETURNING id, order_date, status.
--   f) Verificación DENTRO de la transacción:
--        - órdenes 'Cancelled' 3+ años restantes sin hijos bloqueantes
--          (esperado: 0)
--        - filas archivadas en audit.deleted_rows hoy para 'sales.orders'
--          y 'sales.order_items' (debe coincidir con tu Fase A)
--   g) ROLLBACK al final (es práctica, la purga real corre en la ventana).
--
-- PREGUNTAS DE NEGOCIO (responde en comentario SQL):
--   - ¿Por qué el trigger de archivado hace que esta purga sea "segura"
--     aunque sea un hard delete? ¿Qué información se conserva y dónde?
--   - Si Governance te pidiera purgar TAMBIÉN las órdenes con payments,
--     ¿qué tendría que pasar primero a nivel de datos y de negocio?
--     (No escribas ese SQL, solo argumenta.)
--   - ¿Por qué conviene hacer el DELETE por lotes (batches por rango de
--     id) si fueran 2 millones de órdenes? Menciona al menos 2 razones.
--
-- RESTRICCIONES:
--   - Usa INTERVAL para los 3 años (Día 8).
--   - Usa NOT EXISTS para excluir órdenes con hijos bloqueantes.
--   - Un solo DELETE en la Fase B (no borres order_items manualmente;
--     el CASCADE lo hace).

-- Escribe tu consulta aquí abajo (Fase A):
SELECT
	COUNT(*)
FROM sales.orders o
WHERE o.status = 'Cancelled' AND
	(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '3 years';

SELECT
	COUNT(DISTINCT oi.id)
FROM sales.orders o 
JOIN sales.order_items oi on o.id = oi.order_id
WHERE o.status = 'Cancelled' AND
	(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '3 years';

SELECT
	o.id
FROM sales.orders o 
WHERE o.status = 'Cancelled' AND
	(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '3 years' AND
	(EXISTS(
		SELECT 1
		FROM sales.payments p 
		WHERE p.order_id = o.id) OR
	EXISTS(
		SELECT 1
		FROM sales.invoices i 
		WHERE i.order_id = o.id) OR
	EXISTS(
		SELECT 1
		FROM logistics.shipments sh 
		WHERE sh.order_id = o.id));
-- Hay ordenes con payments invoices o shipments asi que si fallara el borrado
-- En total se borrarian 87 + 358 = 445
-- Escribe tu consulta aquí abajo (Fase B):
DELETE
FROM sales.orders o 
WHERE o.status = 'Cancelled' AND
	(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '3 years' AND
	NOT EXISTS(
		SELECT 1
		FROM sales.payments p 
		WHERE p.order_id = o.id) AND
	not EXISTS(
		SELECT 1
		FROM sales.invoices i 
		WHERE i.order_id = o.id) AND
	not EXISTS(
		SELECT 1
		FROM logistics.shipments sh 
		WHERE sh.order_id = o.id)
RETURNING o.id, o.order_date, o.status;

SELECT
	o.id
FROM sales.orders o 
WHERE o.status = 'Cancelled' AND
	(o.order_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '3 years' AND
	EXISTS(
		SELECT 1
		FROM sales.order_items oi
		WHERE o.id = oi.order_id);

SELECT COUNT(*) AS audit_rows
FROM audit.deleted_rows
WHERE table_name = 'sales.orders'
  AND deleted_at >= CURRENT_DATE;

ROLLBACK;
--RESPUESTAS
-- 1. Es segura porque asi se sabe cuando se borro algo y que se borro 2. primero se tendria que borrar los payments y luego recien los orders pero tambien se tendria que verificar que estas ordenes no tienen shipments o invoices 3. Por rendimiento y porque de esta manera no estariamos lockeando todos esos registros que podrian ser parte de otras consultas o transacciones

-- ============================================================================
-- SOLUCIÓN PROFESIONAL -- Ejercicio 3
-- ============================================================================

-- Fase A: Análisis de impacto
SELECT COUNT(*) AS cancelled_3y
FROM sales.orders
WHERE status = 'Cancelled'
	AND (order_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '3 years';

SELECT COUNT(*) AS items_cascaded
FROM sales.order_items oi
JOIN sales.orders o ON o.id = oi.order_id
WHERE o.status = 'Cancelled'
	AND (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '3 years';

SELECT o.id
FROM sales.orders o
WHERE o.status = 'Cancelled'
	AND (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '3 years'
	AND (EXISTS (SELECT 1 FROM sales.payments p WHERE p.order_id = o.id)
		OR EXISTS (SELECT 1 FROM sales.invoices i WHERE i.order_id = o.id)
		OR EXISTS (SELECT 1 FROM logistics.shipments sh WHERE sh.order_id = o.id));

-- Fase B: Ejecución transaccional
BEGIN;

DELETE FROM sales.orders
WHERE status = 'Cancelled'
	AND (order_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '3 years'
	AND NOT EXISTS (SELECT 1 FROM sales.payments p WHERE p.order_id = sales.orders.id)
	AND NOT EXISTS (SELECT 1 FROM sales.invoices i WHERE i.order_id = sales.orders.id)
	AND NOT EXISTS (SELECT 1 FROM logistics.shipments sh WHERE sh.order_id = sales.orders.id)
RETURNING id, order_date, status;

-- Verificación post-delete (órdenes restantes sin hijos bloqueantes)
SELECT COUNT(*) AS remaining
FROM sales.orders o
WHERE o.status = 'Cancelled'
	AND (o.order_date AT TIME ZONE 'America/Mexico_City')::DATE < CURRENT_DATE - INTERVAL '3 years'
	AND NOT EXISTS (SELECT 1 FROM sales.payments p WHERE p.order_id = o.id)
	AND NOT EXISTS (SELECT 1 FROM sales.invoices i WHERE i.order_id = o.id)
	AND NOT EXISTS (SELECT 1 FROM logistics.shipments sh WHERE sh.order_id = o.id);

-- Verificación de archivado
SELECT table_name, COUNT(*) AS archived
FROM audit.deleted_rows
WHERE deleted_at >= CURRENT_DATE
	AND table_name IN ('sales.orders', 'sales.order_items')
GROUP BY table_name;

ROLLBACK;