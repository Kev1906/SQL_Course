-- ============================================================================
-- SQL Master Course - Day 003 Exercises (DataMartX)
-- Topic: EXISTS y NOT EXISTS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Ejercicio 1 -- Ticket MKT-089: Campaña de re-compra para clientes activos
-- Solicitante: Directora de Marketing
-- Prioridad: Alta
-- ----------------------------------------------------------------------------

-- Queremos lanzar una campaña de email marketing dirigida a clientes que
-- ya compraron al menos una vez. Necesito un listado limpio de clientes
-- activos que tengan AL MENOS UNA orden en estado 'Delivered' (entregada).

-- REQUISITOS:
-- - Mostrar: first_name, last_name, email, segment, country_name.
-- - Solo clientes activos (is_active = TRUE).
-- - Solo clientes con al menos una orden Delivered.
-- - SIN duplicados (cada cliente debe aparecer UNA sola vez).
-- - Orden alfabetico por country_name, luego last_name, luego first_name.

-- RESTRICCIÓN: No uses INNER JOIN con orders. Usa EXISTS.

-- Escribe tu consulta aquí abajo:

SELECT
	c.first_name,
	c.last_name,
	c.email,
	c.segment,
	co."name" as country_name
FROM core.customers c
JOIN core.cities ci on c.city_id = ci.id 
join core.countries co on co.id = ci.country_id
WHERE c.is_active = TRUE AND EXISTS (
	SELECT 1
	FROM sales.orders o 
	WHERE o.customer_id = c.id and o.status = 'Delivered')
ORDER BY co."name", c.last_name, c.first_name;
-- ----------------------------------------------------------------------------
-- Ejercicio 2 -- Ticket CAT-034: Productos sin reseñas
-- Solicitante: Category Manager
-- Prioridad: Media
-- ----------------------------------------------------------------------------

-- El equipo de categorías detectó que hay productos listados en el catálogo
-- que NADIE ha reseñado. Esto es un problema de confianza: un producto sin
-- reviews tiene menos tasa de conversión.

-- Necesito el listado de productos activos que NO tienen NI UNA review.

-- REQUISITOS:
-- - Mostrar: product_name, sku, category_name, supplier_name, price.
-- - Solo productos activos (is_active = TRUE).
-- - Incluir la categoría y el supplier para que el category manager sepa
--   a quién contactar.
-- - Ordenar por category_name, luego price de mayor a menor.

-- RESTRICCIÓN: Usa NOT EXISTS. No uses LEFT JOIN + IS NULL.

-- Escribe tu consulta aquí abajo:

SELECT
	p."name" as product_name,
	p.sku,
	c."name" as category_name,
	s."name" as supplier_name,
	p.price
FROM inventory.products p
JOIN marketing.categories c on c.id = p.category_id
JOIN core.suppliers s on s.id = p.supplier_id
WHERE p.is_active = TRUE and not EXISTS (
	SELECT 1
	FROM marketing.reviews r
	WHERE r.product_id = p.id)
ORDER BY c."name" ASC, p.price DESC; 
-- ----------------------------------------------------------------------------
-- Ejercicio 3 -- Ticket OPS-067: Proveedores con productos fantasma
-- Solicitante: Director de Operaciones
-- Prioridad: Urgente
-- ----------------------------------------------------------------------------

-- Auditoría urgente: encontramos proveedores que tienen productos activos
-- en el catálogo, pero NINGUNO de esos productos tiene stock en NINGUN
-- almacén del país donde está registrado el proveedor.

-- Más concretamente: proveedores cuyo país (a través de city_id -> country_id)
-- coincide con el país de al menos uno de los warehouses donde sus productos
-- tienen stock = 0 (o directamente no tienen registro en stocks).

-- REQUISITOS:
-- - Mostrar: supplier_name, supplier_email, supplier_country,
--   cantidad de productos activos que tiene ese supplier.
-- - Solo suppliers cuyos productos activos NO tienen stock > 0 en warehouses
--   de SU MISMO PAIS.
-- - Ordenar por cantidad de productos activos descendente.

-- PISTA: Necesitas combinar EXISTS y NOT EXISTS, o hacer una doble validación.
-- Piensa: "supplier en país X, cuyos productos activos NO tienen stock > 0
-- en warehouses del país X".

-- RESTRICCIÓN: Usa EXISTS y/o NOT EXISTS. No uses LEFT JOIN + IS NULL.

-- Escribe tu consulta aquí abajo:
SELECT
	s."name" as supplier_name,
	s.email as supplier_email,
	co."name" as supplier_country,
	count(DISTINCT p.id) as active_products
FROM core.suppliers s
JOIN core.cities ci on ci.id = s.city_id
join core.countries co on co.id = ci.country_id
join inventory.products p on p.supplier_id = s.id
WHERE p.is_active = TRUE AND NOT EXISTS(
	SELECT 1
	FROM inventory.stocks s 
	WHERE s.product_id = p.id AND s.quantity > 0)
and EXISTS(
	SELECT 1
	FROM inventory.warehouses w 
	JOIN inventory.stocks sw on sw.warehouse_id = w.id
	join core.cities ciw on ciw.id = w.city_id
	join core.countries cow on cow.id = ci.country_id
	WHERE cow.id = co.id)
GROUP BY co."name", s."name", s.email
ORDER BY count(DISTINCT p.id);

SELECT
    s.name AS supplier_name,
    s.email AS supplier_email,
    co.name AS supplier_country,
    COUNT(DISTINCT p.id) AS active_products
FROM core.suppliers s
JOIN core.cities ci ON ci.id = s.city_id
JOIN core.countries co ON co.id = ci.country_id
JOIN inventory.products p ON p.supplier_id = s.id
WHERE p.is_active = TRUE
  AND NOT EXISTS (
      SELECT 1
      FROM inventory.stocks st
      JOIN inventory.warehouses w ON w.id = st.warehouse_id
      JOIN core.cities ciw ON ciw.id = w.city_id
      WHERE st.product_id = p.id
        AND st.quantity > 0
        AND ciw.country_id = co.id
  )
GROUP BY s.name, s.email, co.name
ORDER BY COUNT(DISTINCT p.id) DESC;