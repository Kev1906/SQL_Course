-- ============================================================================
-- SQL Master Course - Functions & Stored Procedures Definition (DataMartX)
-- Staff Data Engineer Design
-- ============================================================================

-- ----------------------------------------------------------------------------
-- HELPER FUNCTIONS
-- ----------------------------------------------------------------------------

-- Helper function to calculate net prices with percentage and cash discounts.
CREATE OR REPLACE FUNCTION analytics.fn_calculate_net_amount(
    p_price NUMERIC,
    p_quantity INT,
    p_promo_pct NUMERIC DEFAULT 0.00,
    p_coupon_amount NUMERIC DEFAULT 0.00
)
RETURNS NUMERIC AS $$
DECLARE
    v_gross NUMERIC;
    v_discount NUMERIC;
    v_net NUMERIC;
BEGIN
    v_gross := p_price * p_quantity;
    
    -- Apply promo percentage discount first
    v_discount := v_gross * (COALESCE(p_promo_pct, 0.00) / 100.00);
    
    -- Apply coupon flat value discount next
    v_discount := v_discount + COALESCE(p_coupon_amount, 0.00);
    
    v_net := v_gross - v_discount;
    
    -- Floor value at 0.00
    IF v_net < 0.00 THEN
        v_net := 0.00;
    END IF;
    
    RETURN ROUND(v_net, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION analytics.fn_calculate_net_amount IS 'Calculates net amount by applying percentage and flat cash discounts to gross price.';


-- ----------------------------------------------------------------------------
-- TRANSACTIONAL PROCEDURES
-- ----------------------------------------------------------------------------

-- Stored Procedure: sales.sp_place_order
-- Rationale: High-performance transactional routine handling orders.
-- 1. Evaluates products prices, promotions, and coupons.
-- 2. Checks and reserves stock across the closest warehouse containing inventory.
-- 3. Emits inventory movements.
-- 4. Registers invoice and payment dummy structure.
-- All operations are performed under a single database transaction context.
CREATE OR REPLACE PROCEDURE sales.sp_place_order(
    IN p_customer_id BIGINT,
    IN p_employee_id BIGINT,
    IN p_promotion_id BIGINT,
    IN p_coupon_id BIGINT,
    IN p_payment_method sales.payment_method_enum,
    IN p_items JSONB, -- Array of objects: [{"product_id": X, "quantity": Y}, ...]
    OUT p_order_id BIGINT
)
AS $$
DECLARE
    v_item RECORD;
    v_product_price NUMERIC;
    v_product_cost NUMERIC;
    v_promo_pct NUMERIC := 0.00;
    v_coupon_val NUMERIC := 0.00;
    v_coupon_min_purchase NUMERIC := 0.00;
    v_coupon_active BOOLEAN := FALSE;
    v_total_amount NUMERIC := 0.00;
    v_total_discount NUMERIC := 0.00;
    v_net_amount NUMERIC := 0.00;
    v_stock_id BIGINT;
    v_stock_qty INT;
    v_warehouse_id BIGINT;
    v_order_item_subtotal NUMERIC;
    v_order_item_discount NUMERIC;
    v_invoice_number VARCHAR(50);
BEGIN
    -- 1. Validate Customer
    IF NOT EXISTS (SELECT 1 FROM core.customers WHERE id = p_customer_id AND is_active = TRUE) THEN
        RAISE EXCEPTION 'Customer ID % is invalid or inactive', p_customer_id;
    END IF;

    -- 2. Retrieve Coupon Information (if provided)
    IF p_coupon_id IS NOT NULL THEN
        SELECT discount_amount, min_purchase_amount, is_active
        INTO v_coupon_val, v_coupon_min_purchase, v_coupon_active
        FROM marketing.coupons
        WHERE id = p_coupon_id;
        
        IF NOT v_coupon_active THEN
            RAISE EXCEPTION 'Coupon ID % is not active', p_coupon_id;
        END IF;
    END IF;

    -- 3. Retrieve Promotion Percentage (if provided)
    IF p_promotion_id IS NOT NULL THEN
        SELECT discount_percentage
        INTO v_promo_pct
        FROM marketing.promotions
        WHERE id = p_promotion_id AND CURRENT_DATE BETWEEN start_date AND end_date;
        
        IF v_promo_pct IS NULL THEN
            RAISE EXCEPTION 'Promotion ID % is invalid or has expired', p_promotion_id;
        END IF;
    END IF;

    -- 4. Create Order Header
    INSERT INTO sales.orders (
        customer_id, employee_id, promotion_id, coupon_id, order_date, status, total_amount, discount_amount, net_amount
    )
    VALUES (
        p_customer_id, p_employee_id, p_promotion_id, p_coupon_id, CLOCK_TIMESTAMP(), 'Pending', 0.00, 0.00, 0.00
    )
    RETURNING id INTO p_order_id;

    -- 5. Process JSONB items loop
    FOR v_item IN 
        SELECT 
            (value->>'product_id')::BIGINT AS product_id,
            (value->>'quantity')::INT AS quantity
        FROM jsonb_array_elements(p_items)
    LOOP
        -- Check if product exists and active
        SELECT price, cost
        INTO v_product_price, v_product_cost
        FROM inventory.products
        WHERE id = v_item.product_id AND is_active = TRUE;

        IF v_product_price IS NULL THEN
            RAISE EXCEPTION 'Product ID % is not active or does not exist', v_item.product_id;
        END IF;

        -- Check warehouse stock. Look for any warehouse containing enough quantity.
        SELECT s.id, s.warehouse_id, s.quantity
        INTO v_stock_id, v_warehouse_id, v_stock_qty
        FROM inventory.stocks s
        WHERE s.product_id = v_item.product_id AND s.quantity >= v_item.quantity
        LIMIT 1 FOR UPDATE; -- Lock stock row to prevent race conditions

        IF v_stock_id IS NULL THEN
            RAISE EXCEPTION 'Insufficient stock for Product ID %. Requested: %, None available in a single warehouse.', 
                v_item.product_id, v_item.quantity;
        END IF;

        -- Calculate Item Pricing
        v_order_item_discount := ROUND((v_product_price * v_item.quantity) * (v_promo_pct / 100.00), 2);
        v_order_item_subtotal := (v_product_price * v_item.quantity) - v_order_item_discount;

        -- Accumulate Order sums
        v_total_amount := v_total_amount + (v_product_price * v_item.quantity);
        v_total_discount := v_total_discount + v_order_item_discount;

        -- Insert Order Item
        INSERT INTO sales.order_items (
            order_id, product_id, quantity, unit_price, discount_amount, subtotal
        )
        VALUES (
            p_order_id, v_item.product_id, v_item.quantity, v_product_price, v_order_item_discount, v_order_item_subtotal
        );

        -- Decrement Inventory Stock
        UPDATE inventory.stocks
        SET quantity = quantity - v_item.quantity
        WHERE id = v_stock_id;

        -- Log Outbound Movement
        INSERT INTO inventory.movements (
            stock_id, movement_type, quantity, reference_id, movement_date
        )
        VALUES (
            v_stock_id, 'OUTBOUND', -v_item.quantity, p_order_id, CLOCK_TIMESTAMP()
        );
    END LOOP;

    -- Apply Coupon Flat Value if minimum purchase requirement is met
    IF p_coupon_id IS NOT NULL THEN
        IF v_total_amount >= v_coupon_min_purchase THEN
            v_total_discount := v_total_discount + v_coupon_val;
        ELSE
            -- Soft warning in logs but do not block checkout, or we can choose to throw exception.
            -- We'll throw exception for integrity.
            RAISE EXCEPTION 'Minimum purchase amount of % not met for coupon. Order subtotal: %', 
                v_coupon_min_purchase, v_total_amount;
        END IF;
    END IF;

    -- Double-check net amount boundary
    v_net_amount := v_total_amount - v_total_discount;
    IF v_net_amount < 0.00 THEN
        v_net_amount := 0.00;
        v_total_discount := v_total_amount;
    END IF;

    -- Update Order Header Totals and mark as Processing
    UPDATE sales.orders
    SET total_amount = v_total_amount,
        discount_amount = v_total_discount,
        net_amount = v_net_amount,
        status = 'Processing'
    WHERE id = p_order_id;

    -- 6. Trigger Invoice Generation
    v_invoice_number := 'INV-' || TO_CHAR(CLOCK_TIMESTAMP(), 'YYYY') || '-' || LPAD(p_order_id::TEXT, 8, '0');
    INSERT INTO sales.invoices (
        order_id, invoice_number, issue_date, due_date, tax_amount, total_amount, status
    )
    VALUES (
        p_order_id, v_invoice_number, CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days',
        ROUND(v_net_amount * 0.19, 2), -- 19% Tax example
        v_net_amount, 'Unpaid'
    );

    -- 7. Execute Payment
    INSERT INTO sales.payments (
        order_id, payment_date, payment_method, amount, status
    )
    VALUES (
        p_order_id, CLOCK_TIMESTAMP(), p_payment_method, v_net_amount, 'Completed'
    );

    -- Update invoice as Paid and order as Completed (Processing -> Delivered or Shipped)
    UPDATE sales.invoices SET status = 'Paid' WHERE order_id = p_order_id;
    UPDATE sales.orders SET status = 'Shipped' WHERE id = p_order_id;

END;
$$ LANGUAGE plpgsql;

COMMENT ON PROCEDURE sales.sp_place_order IS 'Places transaction orders, validates catalogs, processes pricing, reserves warehouse quantities, issues receipts.';


-- Stored Procedure: inventory.sp_replenish_stock
-- Rationale: Restocks a product catalog item in a specific warehouse facility.
CREATE OR REPLACE PROCEDURE inventory.sp_replenish_stock(
    IN p_warehouse_id BIGINT,
    IN p_product_id BIGINT,
    IN p_quantity INT,
    IN p_employee_id BIGINT
)
AS $$
DECLARE
    v_stock_id BIGINT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Replenish quantity must be positive. Got: %', p_quantity;
    END IF;

    -- Find or create stock entry
    SELECT id INTO v_stock_id
    FROM inventory.stocks
    WHERE warehouse_id = p_warehouse_id AND product_id = p_product_id
    FOR UPDATE;

    IF v_stock_id IS NULL THEN
        INSERT INTO inventory.stocks (warehouse_id, product_id, quantity, reorder_level)
        VALUES (p_warehouse_id, p_product_id, p_quantity, 10)
        RETURNING id INTO v_stock_id;
    ELSE
        UPDATE inventory.stocks
        SET quantity = quantity + p_quantity
        WHERE id = v_stock_id;
    END IF;

    -- Log Movement
    INSERT INTO inventory.movements (
        stock_id, movement_type, quantity, reference_id, movement_date
    )
    VALUES (
        v_stock_id, 'INBOUND', p_quantity, p_employee_id, CLOCK_TIMESTAMP()
    );

END;
$$ LANGUAGE plpgsql;

COMMENT ON PROCEDURE inventory.sp_replenish_stock IS 'Restocks products into warehouses, updates inventory stock levels and issues movement audits.';


-- ----------------------------------------------------------------------------
-- ANALYTICAL REPORTING FUNCTIONS
-- ----------------------------------------------------------------------------

-- Function: analytics.fn_get_customer_metrics
-- Rationale: Fetches analytical dimensions for a given customer. Used in dashboarding.
CREATE OR REPLACE FUNCTION analytics.fn_get_customer_metrics(p_customer_id BIGINT)
RETURNS TABLE (
    total_orders BIGINT,
    gross_spend NUMERIC,
    net_spend NUMERIC,
    preferred_category VARCHAR(100),
    avg_order_value NUMERIC,
    last_purchase_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Ensure customer exists
    IF NOT EXISTS (SELECT 1 FROM core.customers WHERE id = p_customer_id) THEN
        RAISE EXCEPTION 'Customer ID % not found', p_customer_id;
    END IF;

    RETURN QUERY
    WITH customer_orders AS (
        SELECT 
            o.id AS order_id, 
            o.total_amount, 
            o.net_amount, 
            o.order_date
        FROM sales.orders o
        WHERE o.customer_id = p_customer_id AND o.status NOT IN ('Cancelled')
    ),
    category_counts AS (
        SELECT 
            p.category_id,
            cat.name AS category_name,
            COUNT(*) AS items_purchased,
            ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) as rank
        FROM sales.orders o
        INNER JOIN sales.order_items oi ON o.id = oi.order_id
        INNER JOIN inventory.products p ON oi.product_id = p.id
        INNER JOIN marketing.categories cat ON p.category_id = cat.id
        WHERE o.customer_id = p_customer_id AND o.status NOT IN ('Cancelled')
        GROUP BY p.category_id, cat.name
    )
    SELECT
        COALESCE(COUNT(co.order_id), 0::bigint) AS total_orders,
        COALESCE(SUM(co.total_amount), 0.00) AS gross_spend,
        COALESCE(SUM(co.net_amount), 0.00) AS net_spend,
        COALESCE((SELECT cc.category_name FROM category_counts cc WHERE cc.rank = 1), 'None') AS preferred_category,
        COALESCE(ROUND(AVG(co.net_amount), 2), 0.00) AS avg_order_value,
        MAX(co.order_date) AS last_purchase_date
    FROM customer_orders co;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION analytics.fn_get_customer_metrics IS 'Returns structured table containing orders count, total spent, preferences and dates for a specific customer ID.';
