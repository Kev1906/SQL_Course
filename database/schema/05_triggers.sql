-- ============================================================================
-- SQL Master Course - Triggers Definition (DataMartX)
-- Staff Data Engineer Design
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TIMESTAMP MANAGEMENT TRIGGER
-- ----------------------------------------------------------------------------

-- Universal function to update the updated_at column to current time.
CREATE OR REPLACE FUNCTION core.fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION core.fn_update_timestamp IS 'Sets the updated_at timestamp to the current clock time during row update operations.';

-- Attach update timestamp triggers to all tables containing updated_at column
CREATE TRIGGER tr_countries_timestamp BEFORE UPDATE ON core.countries FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_cities_timestamp BEFORE UPDATE ON core.cities FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_customers_timestamp BEFORE UPDATE ON core.customers FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_suppliers_timestamp BEFORE UPDATE ON core.suppliers FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_departments_timestamp BEFORE UPDATE ON hr.departments FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_employees_timestamp BEFORE UPDATE ON hr.employees FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_categories_timestamp BEFORE UPDATE ON marketing.categories FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_promotions_timestamp BEFORE UPDATE ON marketing.promotions FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_coupons_timestamp BEFORE UPDATE ON marketing.coupons FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_products_timestamp BEFORE UPDATE ON inventory.products FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_warehouses_timestamp BEFORE UPDATE ON inventory.warehouses FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_stocks_timestamp BEFORE UPDATE ON inventory.stocks FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_movements_timestamp BEFORE UPDATE ON inventory.movements FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_reviews_timestamp BEFORE UPDATE ON marketing.reviews FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_orders_timestamp BEFORE UPDATE ON sales.orders FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_order_items_timestamp BEFORE UPDATE ON sales.order_items FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_payments_timestamp BEFORE UPDATE ON sales.payments FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_invoices_timestamp BEFORE UPDATE ON sales.invoices FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_shippers_timestamp BEFORE UPDATE ON logistics.shippers FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_shipments_timestamp BEFORE UPDATE ON logistics.shipments FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();
CREATE TRIGGER tr_returns_timestamp BEFORE UPDATE ON logistics.returns FOR EACH ROW EXECUTE FUNCTION core.fn_update_timestamp();


-- ----------------------------------------------------------------------------
-- 2. AUDIT LOG TRIGGER (Sensitive tables: products, employees, orders)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit.fn_audit_log_change()
RETURNS TRIGGER AS $$
DECLARE
    v_old_json JSONB := NULL;
    v_new_json JSONB := NULL;
    v_action audit.action_enum;
BEGIN
    IF (TG_OP = 'DELETE') THEN
        v_action := 'DELETE';
        v_old_json := to_jsonb(OLD);
    ELSIF (TG_OP = 'UPDATE') THEN
        v_action := 'UPDATE';
        v_old_json := to_jsonb(OLD);
        v_new_json := to_jsonb(NEW);
    ELSIF (TG_OP = 'INSERT') THEN
        v_action := 'INSERT';
        v_new_json := to_jsonb(NEW);
    END IF;

    INSERT INTO audit.logs (
        table_name, action, old_values, new_values, performed_by
    )
    VALUES (
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        v_action,
        v_old_json,
        v_new_json,
        session_user
    );

    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION audit.fn_audit_log_change IS 'Captures data mutations on sensitive tables and posts payload changes into audit.logs table.';

-- Attach Audit Log Triggers
CREATE TRIGGER tr_audit_products AFTER INSERT OR UPDATE OR DELETE ON inventory.products FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_log_change();
CREATE TRIGGER tr_audit_employees AFTER INSERT OR UPDATE OR DELETE ON hr.employees FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_log_change();
CREATE TRIGGER tr_audit_orders AFTER INSERT OR UPDATE OR DELETE ON sales.orders FOR EACH ROW EXECUTE FUNCTION audit.fn_audit_log_change();


-- ----------------------------------------------------------------------------
-- 3. SOFT-DELETE ARCHIVING TRIGGER (Archive deleted rows for customers, orders)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION audit.fn_archive_deleted_row()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit.deleted_rows (
        table_name, deleted_by, deleted_at, original_id, original_uuid, original_data
    )
    VALUES (
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        session_user,
        CURRENT_TIMESTAMP,
        OLD.id,
        OLD.uuid,
        to_jsonb(OLD)
    );
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION audit.fn_archive_deleted_row IS 'Safely dumps hard-deleted rows into audit.deleted_rows archive structure before physical purge.';

-- Attach soft-delete archive triggers
CREATE TRIGGER tr_archive_customers BEFORE DELETE ON core.customers FOR EACH ROW EXECUTE FUNCTION audit.fn_archive_deleted_row();
CREATE TRIGGER tr_archive_orders BEFORE DELETE ON sales.orders FOR EACH ROW EXECUTE FUNCTION audit.fn_archive_deleted_row();
CREATE TRIGGER tr_archive_order_items BEFORE DELETE ON sales.order_items FOR EACH ROW EXECUTE FUNCTION audit.fn_archive_deleted_row();
