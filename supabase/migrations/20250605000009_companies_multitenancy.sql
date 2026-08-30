-- Societăți (multi-tenant): date și utilizatori legați de societatea curentă

CREATE TABLE public.companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    denumire TEXT NOT NULL,
    cui TEXT,
    nr_reg_com TEXT,
    adresa TEXT,
    iban TEXT,
    email TEXT,
    telefon TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.user_company_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    can_view BOOLEAN NOT NULL DEFAULT false,
    can_create BOOLEAN NOT NULL DEFAULT false,
    can_edit BOOLEAN NOT NULL DEFAULT false,
    can_delete BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, company_id)
);

ALTER TABLE public.user_profiles
    ADD COLUMN selected_company_id UUID REFERENCES public.companies(id) ON DELETE SET NULL;

ALTER TABLE public.suppliers
    ADD COLUMN company_id UUID REFERENCES public.companies(id) ON DELETE RESTRICT;

ALTER TABLE public.supplier_invoices
    ADD COLUMN company_id UUID REFERENCES public.companies(id) ON DELETE RESTRICT;

ALTER TABLE public.supplier_payments
    ADD COLUMN company_id UUID REFERENCES public.companies(id) ON DELETE RESTRICT;

CREATE INDEX idx_companies_denumire ON public.companies(denumire);
CREATE INDEX idx_companies_is_active ON public.companies(is_active);
CREATE INDEX idx_user_company_permissions_user ON public.user_company_permissions(user_id);
CREATE INDEX idx_user_company_permissions_company ON public.user_company_permissions(company_id);
CREATE INDEX idx_suppliers_company ON public.suppliers(company_id);
CREATE INDEX idx_supplier_invoices_company ON public.supplier_invoices(company_id);
CREATE INDEX idx_supplier_payments_company ON public.supplier_payments(company_id);
CREATE INDEX idx_user_profiles_selected_company ON public.user_profiles(selected_company_id);

CREATE TRIGGER companies_updated_at
    BEFORE UPDATE ON public.companies
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.current_user_selected_company_id()
RETURNS UUID AS $$
    SELECT selected_company_id
    FROM public.user_profiles
    WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_user_has_company_access(
    p_company_id UUID,
    p_action TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_company_id IS NULL THEN
        RETURN false;
    END IF;

    IF public.is_current_user_admin() THEN
        RETURN true;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.user_company_permissions ucp
        WHERE ucp.user_id = auth.uid()
          AND ucp.company_id = p_company_id
          AND (
            (p_action = 'view' AND ucp.can_view)
            OR (p_action IN ('create', 'insert') AND ucp.can_create)
            OR (p_action IN ('edit', 'update') AND ucp.can_edit)
            OR (p_action = 'delete' AND ucp.can_delete)
          )
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_user_can_access_selected_company_data(
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

    RETURN public.current_user_can_supplier_module(p_module_action)
        AND public.current_user_has_company_access(p_company_id, p_company_action);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_company_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "companies_select" ON public.companies FOR SELECT TO authenticated
    USING (
        public.is_current_user_admin()
        OR public.current_user_has_company_access(id, 'view')
    );

CREATE POLICY "companies_insert" ON public.companies FOR INSERT TO authenticated
    WITH CHECK (public.is_current_user_admin());

CREATE POLICY "companies_update" ON public.companies FOR UPDATE TO authenticated
    USING (public.is_current_user_admin())
    WITH CHECK (public.is_current_user_admin());

CREATE POLICY "companies_delete" ON public.companies FOR DELETE TO authenticated
    USING (public.is_current_user_admin());

CREATE POLICY "user_company_permissions_select" ON public.user_company_permissions FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_current_user_admin()
    );

CREATE POLICY "user_company_permissions_insert" ON public.user_company_permissions FOR INSERT TO authenticated
    WITH CHECK (public.is_current_user_admin());

CREATE POLICY "user_company_permissions_update" ON public.user_company_permissions FOR UPDATE TO authenticated
    USING (public.is_current_user_admin())
    WITH CHECK (public.is_current_user_admin());

CREATE POLICY "user_company_permissions_delete" ON public.user_company_permissions FOR DELETE TO authenticated
    USING (public.is_current_user_admin());

DROP POLICY IF EXISTS "suppliers_select" ON public.suppliers;
DROP POLICY IF EXISTS "suppliers_insert" ON public.suppliers;
DROP POLICY IF EXISTS "suppliers_update" ON public.suppliers;
DROP POLICY IF EXISTS "suppliers_delete" ON public.suppliers;
DROP POLICY IF EXISTS "invoices_select" ON public.supplier_invoices;
DROP POLICY IF EXISTS "invoices_insert" ON public.supplier_invoices;
DROP POLICY IF EXISTS "invoices_update" ON public.supplier_invoices;
DROP POLICY IF EXISTS "invoices_delete" ON public.supplier_invoices;
DROP POLICY IF EXISTS "payments_select" ON public.supplier_payments;
DROP POLICY IF EXISTS "payments_insert" ON public.supplier_payments;
DROP POLICY IF EXISTS "payments_update" ON public.supplier_payments;
DROP POLICY IF EXISTS "payments_delete" ON public.supplier_payments;

CREATE POLICY "suppliers_select" ON public.suppliers FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE POLICY "suppliers_insert" ON public.suppliers FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'create', 'create'));

CREATE POLICY "suppliers_update" ON public.suppliers FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'));

CREATE POLICY "suppliers_delete" ON public.suppliers FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete'));

CREATE POLICY "invoices_select" ON public.supplier_invoices FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE POLICY "invoices_insert" ON public.supplier_invoices FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'create', 'create'));

CREATE POLICY "invoices_update" ON public.supplier_invoices FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'));

CREATE POLICY "invoices_delete" ON public.supplier_invoices FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete'));

CREATE POLICY "payments_select" ON public.supplier_payments FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE POLICY "payments_insert" ON public.supplier_payments FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'create', 'create'));

CREATE POLICY "payments_update" ON public.supplier_payments FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'));

CREATE POLICY "payments_delete" ON public.supplier_payments FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete'));
