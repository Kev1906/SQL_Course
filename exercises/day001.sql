-- Ejercicio 1
SELECT c.id, c.last_name, c.first_name, c.created_at, COUNT(o.id) as cantidad_ordenes
FROM core.customers AS c left JOIN sales.orders as o on c.id = o.customer_id GROUP BY c.id, c.last_name, c.first_name, c.created_at;
-- Ejercicio 2
SELECT c.id, c.last_name, c.first_name, COUNT(DISTINCT o.id) as cantidad_ordenes, sum(oi.quantity * oi.unit_price) as total_spent
FROM core.customers AS c JOIN sales.orders as o on c.id = o.customer_id join sales.order_items as oi on o.id = oi.order_id WHERE o.status='Completed' GROUP BY c.id, c.last_name, c.first_name;
-- Ejercicio 3
-- Si me da el numero pero hay algunos problemas *Al traer solo el Id no sabemos a que cliente corresponde el id *Al hacer un inner join nos estmamos perdiendo de aquellos clientes que tienen 0 ordenes que dependiendo del caso pueden o no ser relevantes para el analisis