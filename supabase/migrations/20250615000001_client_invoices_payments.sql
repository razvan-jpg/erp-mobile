-- Modul: Clienți (facturi, plăți, scadente)

CREATE TABLE public.clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    denumire TEXT NOT NULL,
    cui TEXT,
    nr_reg_com TEXT,
    adresa TEXT,
    iban TEXT,
    email TEXT,
    telefon TEXT,
    observatii TEXT,
    nr_zile_scadenta INTEGER NOT NULL DEFAULT 0 CHECK (nr_zile_scadenta >= 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.client_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
    numar_factura TEXT NOT NULL,
    data_factura DATE NOT NULL DEFAULT CURRENT_DATE,
    data_scadenta DATE,
    suma_totala NUMERIC(14, 2) NOT NULL CHECK (suma_totala >= 0),
    suma_tva NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (suma_tva >= 0),
    suma_platita NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (suma_platita >= 0),
    moneda TEXT NOT NULL DEFAULT 'RON',
    status TEXT NOT NULL DEFAULT 'neplatita'
        CHECK (status IN ('neplatita', 'partial', 'platita', 'anulata')),
    observatii TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (client_id, numar_factura)
);

CREATE TABLE public.client_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
    invoice_id UUID REFERENCES public.client_invoices(id) ON DELETE SET NULL,
    data_plata DATE NOT NULL DEFAULT CURRENT_DATE,
    suma NUMERIC(14, 2) NOT NULL CHECK (suma > 0),
    metoda_plata TEXT NOT NULL DEFAULT 'transfer'
        CHECK (metoda_plata IN ('transfer', 'numerar', 'card', 'altele')),
    referinta TEXT,
    observatii TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_clients_company ON public.clients(company_id);
CREATE INDEX idx_clients_denumire ON public.clients(denumire);
CREATE INDEX idx_clients_is_active ON public.clients(is_active);
CREATE INDEX idx_client_invoices_company ON public.client_invoices(company_id);
CREATE INDEX idx_client_invoices_client ON public.client_invoices(client_id);
CREATE INDEX idx_client_invoices_status ON public.client_invoices(status);
CREATE INDEX idx_client_invoices_scadenta ON public.client_invoices(data_scadenta);
CREATE INDEX idx_client_payments_company ON public.client_payments(company_id);
CREATE INDEX idx_client_payments_client ON public.client_payments(client_id);
CREATE INDEX idx_client_payments_invoice ON public.client_payments(invoice_id);

CREATE TRIGGER clients_updated_at
    BEFORE UPDATE ON public.clients
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER client_invoices_updated_at
    BEFORE UPDATE ON public.client_invoices
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.refresh_client_invoice_payment_totals(p_invoice_id UUID)
RETURNS VOID AS $$
DECLARE
    v_total NUMERIC(14, 2);
    v_paid NUMERIC(14, 2);
    v_status TEXT;
BEGIN
    IF p_invoice_id IS NULL THEN
        RETURN;
    END IF;

    SELECT suma_totala INTO v_total
    FROM public.client_invoices WHERE id = p_invoice_id;

    SELECT COALESCE(SUM(suma), 0) INTO v_paid
    FROM public.client_payments WHERE invoice_id = p_invoice_id;

    IF (SELECT status FROM public.client_invoices WHERE id = p_invoice_id) = 'anulata' THEN
        v_status := 'anulata';
    ELSIF v_paid <= 0 THEN
        v_status := 'neplatita';
    ELSIF v_paid >= v_total THEN
        v_status := 'platita';
    ELSE
        v_status := 'partial';
    END IF;

    UPDATE public.client_invoices
    SET suma_platita = v_paid, status = v_status, updated_at = now()
    WHERE id = p_invoice_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.on_client_payment_changed()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM public.refresh_client_invoice_payment_totals(OLD.invoice_id);
        RETURN OLD;
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.invoice_id IS DISTINCT FROM NEW.invoice_id THEN
        PERFORM public.refresh_client_invoice_payment_totals(OLD.invoice_id);
    END IF;

    PERFORM public.refresh_client_invoice_payment_totals(NEW.invoice_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER client_payments_refresh_invoice
    AFTER INSERT OR UPDATE OR DELETE ON public.client_payments
    FOR EACH ROW EXECUTE FUNCTION public.on_client_payment_changed();

CREATE OR REPLACE FUNCTION public.current_user_can_client_module(p_action TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF public.is_current_user_admin() THEN
        RETURN true;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.user_module_permissions ump
        JOIN public.modules m ON m.id = ump.module_id
        WHERE ump.user_id = auth.uid()
          AND m.code = 'client_invoices_payments'
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

CREATE OR REPLACE FUNCTION public.current_user_can_access_selected_company_client_data(
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

    RETURN public.current_user_can_client_module(p_module_action)
        AND public.current_user_has_company_access(p_company_id, p_company_action);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "clients_select" ON public.clients FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'view', 'view'));

CREATE POLICY "clients_insert" ON public.clients FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_client_data(company_id, 'create', 'create'));

CREATE POLICY "clients_update" ON public.clients FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_client_data(company_id, 'edit', 'edit'));

CREATE POLICY "clients_delete" ON public.clients FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'delete', 'delete'));

CREATE POLICY "client_invoices_select" ON public.client_invoices FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'view', 'view'));

CREATE POLICY "client_invoices_insert" ON public.client_invoices FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_client_data(company_id, 'create', 'create'));

CREATE POLICY "client_invoices_update" ON public.client_invoices FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_client_data(company_id, 'edit', 'edit'));

CREATE POLICY "client_invoices_delete" ON public.client_invoices FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'delete', 'delete'));

CREATE POLICY "client_payments_select" ON public.client_payments FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'view', 'view'));

CREATE POLICY "client_payments_insert" ON public.client_payments FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_client_data(company_id, 'create', 'create'));

CREATE POLICY "client_payments_update" ON public.client_payments FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_client_data(company_id, 'edit', 'edit'));

CREATE POLICY "client_payments_delete" ON public.client_payments FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_client_data(company_id, 'delete', 'delete'));

CREATE OR REPLACE FUNCTION public.delete_client(p_client_id UUID)
RETURNS VOID AS $$
DECLARE
    v_company_id UUID;
BEGIN
    SELECT company_id
    INTO v_company_id
    FROM public.clients
    WHERE id = p_client_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'CLIENT_NOT_FOUND';
    END IF;

    IF NOT public.current_user_can_access_selected_company_client_data(v_company_id, 'delete', 'delete') THEN
        RAISE EXCEPTION 'CLIENT_DELETE_FORBIDDEN';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.client_invoices
        WHERE client_id = p_client_id
    ) THEN
        RAISE EXCEPTION 'CLIENT_HAS_INVOICES';
    END IF;

    DELETE FROM public.clients
    WHERE id = p_client_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.delete_client(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_client_invoice(p_invoice_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_can_delete BOOLEAN := false;
BEGIN
    SELECT company_id
    INTO v_company_id
    FROM public.client_invoices
    WHERE id = p_invoice_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'INVOICE_NOT_FOUND';
    END IF;

    v_can_delete := public.is_current_user_superadmin()
        OR (
            public.is_current_user_company_admin()
            AND public.current_user_has_company_access(v_company_id, 'delete')
        )
        OR public.current_user_can_access_selected_company_client_data(v_company_id, 'delete', 'delete');

    IF NOT v_can_delete THEN
        RAISE EXCEPTION 'INVOICE_DELETE_FORBIDDEN';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.client_payments
        WHERE invoice_id = p_invoice_id
    ) THEN
        RAISE EXCEPTION 'INVOICE_HAS_PAYMENTS';
    END IF;

    DELETE FROM public.client_invoices
    WHERE id = p_invoice_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVOICE_NOT_FOUND';
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_client_invoice(UUID) TO authenticated;

INSERT INTO public.modules (code, name, description, sort_order)
VALUES (
    'client_invoices_payments',
    'Clienți',
    'Înregistrare clienți, facturi emise, scadente, plăți și rapoarte Z case de marcat.',
    12
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = true;

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
    client_mod.id,
    ump.can_view,
    ump.can_create,
    ump.can_edit,
    ump.can_delete
FROM public.user_module_permissions ump
JOIN public.modules supplier_mod ON supplier_mod.id = ump.module_id AND supplier_mod.code = 'supplier_invoices_payments'
JOIN public.modules client_mod ON client_mod.code = 'client_invoices_payments'
ON CONFLICT (user_id, module_id) DO UPDATE SET
    can_view = EXCLUDED.can_view OR public.user_module_permissions.can_view,
    can_create = EXCLUDED.can_create OR public.user_module_permissions.can_create,
    can_edit = EXCLUDED.can_edit OR public.user_module_permissions.can_edit,
    can_delete = EXCLUDED.can_delete OR public.user_module_permissions.can_delete;
