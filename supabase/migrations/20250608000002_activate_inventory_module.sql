-- Activare modul Stocuri + permisiuni și RLS dedicate.

INSERT INTO public.modules (code, name, description, sort_order)
VALUES (
    'inventory',
    'Stocuri',
    'Vizualizare stocuri produse și istoric mișcări generate din facturile furnizor.',
    20
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = true;

CREATE OR REPLACE FUNCTION public.current_user_can_inventory_module(p_action TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF public.is_current_user_superadmin() THEN
        RETURN true;
    END IF;

    IF public.is_current_user_company_admin() THEN
        RETURN true;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.user_module_permissions ump
        JOIN public.modules m ON m.id = ump.module_id
        WHERE ump.user_id = auth.uid()
          AND m.code = 'inventory'
          AND m.is_active = true
          AND (
            (p_action = 'view' AND ump.can_view)
            OR (p_action IN ('create', 'insert') AND ump.can_create)
            OR (p_action IN ('edit', 'update') AND ump.can_edit)
            OR (p_action = 'delete' AND ump.can_delete)
          )
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_user_can_access_selected_company_inventory_data(
    p_company_id UUID,
    p_module_action TEXT,
    p_company_action TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_company_id IS NULL THEN
        RETURN false;
    END IF;

    IF p_company_id IS DISTINCT FROM public.current_user_selected_company_id() THEN
        RETURN false;
    END IF;

    RETURN public.current_user_can_inventory_module(p_module_action)
        AND public.current_user_has_company_access(p_company_id, p_company_action);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Copiere drepturi de la modulul furnizori către stocuri (utilizatori existenți).
INSERT INTO public.user_module_permissions (
    user_id,
    module_id,
    can_view,
    can_create,
    can_edit,
    can_delete
)
SELECT
    ump.user_id,
    inv.id,
    ump.can_view,
    ump.can_create,
    ump.can_edit,
    ump.can_delete
FROM public.user_module_permissions ump
JOIN public.modules sup ON sup.id = ump.module_id AND sup.code = 'supplier_invoices_payments'
JOIN public.modules inv ON inv.code = 'inventory'
ON CONFLICT (user_id, module_id) DO UPDATE SET
    can_view = EXCLUDED.can_view OR public.user_module_permissions.can_view,
    can_create = EXCLUDED.can_create OR public.user_module_permissions.can_create,
    can_edit = EXCLUDED.can_edit OR public.user_module_permissions.can_edit,
    can_delete = EXCLUDED.can_delete OR public.user_module_permissions.can_delete;

DROP POLICY IF EXISTS "product_stocks_select" ON public.product_stocks;
DROP POLICY IF EXISTS "product_stocks_insert" ON public.product_stocks;
DROP POLICY IF EXISTS "product_stocks_update" ON public.product_stocks;
DROP POLICY IF EXISTS "product_stocks_delete" ON public.product_stocks;

CREATE POLICY "product_stocks_select" ON public.product_stocks FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'view', 'view'));

CREATE POLICY "product_stocks_insert" ON public.product_stocks FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_inventory_data(company_id, 'create', 'create'));

CREATE POLICY "product_stocks_update" ON public.product_stocks FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_inventory_data(company_id, 'edit', 'edit'));

CREATE POLICY "product_stocks_delete" ON public.product_stocks FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'delete', 'delete'));

DROP POLICY IF EXISTS "stock_movements_select" ON public.stock_movements;
DROP POLICY IF EXISTS "stock_movements_insert" ON public.stock_movements;
DROP POLICY IF EXISTS "stock_movements_update" ON public.stock_movements;
DROP POLICY IF EXISTS "stock_movements_delete" ON public.stock_movements;

CREATE POLICY "stock_movements_select" ON public.stock_movements FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'view', 'view'));

CREATE POLICY "stock_movements_insert" ON public.stock_movements FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_inventory_data(company_id, 'create', 'create'));

CREATE POLICY "stock_movements_update" ON public.stock_movements FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_inventory_data(company_id, 'edit', 'edit'));

CREATE POLICY "stock_movements_delete" ON public.stock_movements FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'delete', 'delete'));

CREATE POLICY "products_select_inventory_module" ON public.products FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'view', 'view'));
