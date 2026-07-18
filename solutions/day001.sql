-- ============================================================================
-- SQL Master Course - Day 001 Solutions (DataMartX)
-- Level: Intermediate
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SOLUTIONS AND ANSWER KEY
-- ----------------------------------------------------------------------------


-- CHALLENGE 1: Customer Directory with Country and Region
-- Goal: Retrieve a list of all active customers, showing their full name (First Last),
-- email, city name, country name, and geographical region.
-- Order the results alphabetically by country name, then city name, then customer last name.

SELECT
    c.first_name || ' ' || c.last_name AS customer_full_name,
    c.email,
    city.name AS city_name,
    country.name AS country_name,
    country.region
FROM core.customers c
INNER JOIN core.cities city ON c.city_id = city.id
INNER JOIN core.countries country ON city.country_id = country.id
WHERE c.is_active = TRUE
ORDER BY country.name, city.name, c.last_name;


-- CHALLENGE 2: Premium Customer Purchase Statistics
-- Goal: Write a query to analyze the purchase history of "Premium" segment customers.
-- For each customer, count their total orders (excluding Cancelled ones), 
-- sum their total spent (net_amount), calculate their average order net value, 
-- and find their most recent purchase date.
-- Only show customers who have spent more than $5,000 in total.
-- Sort by total spent in descending order.

SELECT
    c.id AS customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.segment,
    COUNT(o.id) AS total_orders,
    SUM(o.net_amount) AS total_spent,
    ROUND(AVG(o.net_amount), 2) AS average_order_value,
    MAX(o.order_date) AS last_purchase_date
FROM core.customers c
INNER JOIN sales.orders o ON c.id = o.customer_id
WHERE c.segment = 'Premium' 
  AND o.status NOT IN ('Cancelled')
GROUP BY c.id, c.first_name, c.last_name, c.segment
HAVING SUM(o.net_amount) > 5000.00
ORDER BY total_spent DESC;


-- CHALLENGE 3: Out of Stock Catalog Audit
-- Goal: Identify which products are currently out of stock (quantity = 0) in each warehouse.
-- Display the warehouse name, city location, product name, product SKU, and the product cost.
-- Sort by warehouse name, then product name.

SELECT
    w.name AS warehouse_name,
    city.name AS city_location,
    p.name AS product_name,
    p.sku AS product_sku,
    p.cost AS unit_cost
FROM inventory.stocks s
INNER JOIN inventory.warehouses w ON s.warehouse_id = w.id
INNER JOIN core.cities city ON w.city_id = city.id
INNER JOIN inventory.products p ON s.product_id = p.id
WHERE s.quantity = 0
ORDER BY w.name, p.name;


-- CHALLENGE 4: Top Assisting Sales Employees
-- Goal: Find the top 5 employees who have assisted with the highest volume of sales 
-- (by sum of net_amount of processing/completed orders).
-- Output the employee ID, full name, job title, department name, and the sum of net sales assisted.
-- Sort the results by total sales in descending order.

SELECT
    e.id AS employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.job_title,
    d.name AS department_name,
    SUM(o.net_amount) AS total_sales_assisted
FROM hr.employees e
INNER JOIN hr.departments d ON e.department_id = d.id
INNER JOIN sales.orders o ON e.id = o.employee_id
WHERE o.status IN ('Processing', 'Shipped', 'Delivered')
GROUP BY e.id, e.first_name, e.last_name, e.job_title, d.name
ORDER BY total_sales_assisted DESC
LIMIT 5;


-- CHALLENGE 5: Supplier-Category Alignment Check
-- Goal: Audit the relationship between products and suppliers.
-- List all categories that have products supplied by merchants whose contact details 
-- contain 'gmail.com' or 'hotmail.com' (simulate standard public email checks for small suppliers).
-- Display unique category names and the count of distinct products supplied.
-- Sort by product count in descending order.

SELECT
    cat.name AS category_name,
    COUNT(DISTINCT p.id) AS products_supplied_count
FROM inventory.products p
INNER JOIN marketing.categories cat ON p.category_id = cat.id
INNER JOIN core.suppliers s ON p.supplier_id = s.id
WHERE s.email LIKE '%gmail.com' OR s.email LIKE '%hotmail.com'
GROUP BY cat.name
ORDER BY products_supplied_count DESC;
