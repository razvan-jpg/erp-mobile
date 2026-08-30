-- Activare modul Produse + permisiuni și RLS dedicate.

INSERT INTO public.modules (code, name, description, sort_order)
VALUES (
    'products',
    'Produse',
    'Catalog, gestionare produse finite, rețete, materii prime și mărfuri, obiecte de inventar.',
    30
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = true;

CREATE OR REPLACE FUNCTION public.current_user_can_products_module(p_action TEXT)
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
          AND m.code = 'products'
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

CREATE OR REPLACE FUNCTION public.current_user_can_access_selected_company_products_data(
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

    RETURN public.current_user_can_products_module(p_module_action)
        AND public.current_user_has_company_access(p_company_id, p_company_action);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Copiere drepturi de la modulul Stocuri către Produse (utilizatori existenți).
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
    prod.id,
    ump.can_view,
    ump.can_create,
    ump.can_edit,
    ump.can_delete
FROM public.user_module_permissions ump
JOIN public.modules inv ON inv.id = ump.module_id AND inv.code = 'inventory'
JOIN public.modules prod ON prod.code = 'products'
ON CONFLICT (user_id, module_id) DO UPDATE SET
    can_view = EXCLUDED.can_view OR public.user_module_permissions.can_view,
    can_create = EXCLUDED.can_create OR public.user_module_permissions.can_create,
    can_edit = EXCLUDED.can_edit OR public.user_module_permissions.can_edit,
    can_delete = EXCLUDED.can_delete OR public.user_module_permissions.can_delete;

CREATE POLICY "products_select_products_module" ON public.products FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_products_data(company_id, 'view', 'view'));

CREATE POLICY "products_insert_products_module" ON public.products FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_products_data(company_id, 'create', 'create'));

CREATE POLICY "products_update_products_module" ON public.products FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_products_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_products_data(company_id, 'edit', 'edit'));

CREATE POLICY "products_delete_products_module" ON public.products FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_products_data(company_id, 'delete', 'delete'));
