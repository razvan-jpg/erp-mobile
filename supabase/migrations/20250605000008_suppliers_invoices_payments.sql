-- Modul: Gestionare facturi furnizori / Plăți

CREATE TABLE public.suppliers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    denumire TEXT NOT NULL,
    cui TEXT,
    nr_reg_com TEXT,
    adresa TEXT,
    iban TEXT,
    email TEXT,
    telefon TEXT,
    observatii TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.supplier_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE RESTRICT,
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
    UNIQUE (supplier_id, numar_factura)
);

CREATE TABLE public.supplier_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE RESTRICT,
    invoice_id UUID REFERENCES public.supplier_invoices(id) ON DELETE SET NULL,
    data_plata DATE NOT NULL DEFAULT CURRENT_DATE,
    suma NUMERIC(14, 2) NOT NULL CHECK (suma > 0),
    metoda_plata TEXT NOT NULL DEFAULT 'transfer'
        CHECK (metoda_plata IN ('transfer', 'numerar', 'card', 'altele')),
    referinta TEXT,
    observatii TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_suppliers_denumire ON public.suppliers(denumire);
CREATE INDEX idx_suppliers_is_active ON public.suppliers(is_active);
CREATE INDEX idx_supplier_invoices_supplier ON public.supplier_invoices(supplier_id);
CREATE INDEX idx_supplier_invoices_status ON public.supplier_invoices(status);
CREATE INDEX idx_supplier_invoices_scadenta ON public.supplier_invoices(data_scadenta);
CREATE INDEX idx_supplier_payments_supplier ON public.supplier_payments(supplier_id);
CREATE INDEX idx_supplier_payments_invoice ON public.supplier_payments(invoice_id);

CREATE TRIGGER suppliers_updated_at
    BEFORE UPDATE ON public.suppliers
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER supplier_invoices_updated_at
    BEFORE UPDATE ON public.supplier_invoices
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Recalculează suma_platita și statusul facturii
CREATE OR REPLACE FUNCTION public.refresh_invoice_payment_totals(p_invoice_id UUID)
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
    FROM public.supplier_invoices WHERE id = p_invoice_id;

    SELECT COALESCE(SUM(suma), 0) INTO v_paid
    FROM public.supplier_payments WHERE invoice_id = p_invoice_id;

    IF (SELECT status FROM public.supplier_invoices WHERE id = p_invoice_id) = 'anulata' THEN
        v_status := 'anulata';
    ELSIF v_paid <= 0 THEN
        v_status := 'neplatita';
    ELSIF v_paid >= v_total THEN
        v_status := 'platita';
    ELSE
        v_status := 'partial';
    END IF;

    UPDATE public.supplier_invoices
    SET suma_platita = v_paid, status = v_status, updated_at = now()
    WHERE id = p_invoice_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.on_supplier_payment_changed()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM public.refresh_invoice_payment_totals(OLD.invoice_id);
        RETURN OLD;
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.invoice_id IS DISTINCT FROM NEW.invoice_id THEN
        PERFORM public.refresh_invoice_payment_totals(OLD.invoice_id);
    END IF;

    PERFORM public.refresh_invoice_payment_totals(NEW.invoice_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER supplier_payments_refresh_invoice
    AFTER INSERT OR UPDATE OR DELETE ON public.supplier_payments
    FOR EACH ROW EXECUTE FUNCTION public.on_supplier_payment_changed();

-- Permisiuni modul supplier_invoices_payments
CREATE OR REPLACE FUNCTION public.current_user_can_supplier_module(p_action TEXT)
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
          AND m.code = 'supplier_invoices_payments'
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

ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "suppliers_select" ON public.suppliers FOR SELECT TO authenticated
    USING (public.current_user_can_supplier_module('view'));

CREATE POLICY "suppliers_insert" ON public.suppliers FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_supplier_module('create'));

CREATE POLICY "suppliers_update" ON public.suppliers FOR UPDATE TO authenticated
    USING (public.current_user_can_supplier_module('edit'))
    WITH CHECK (public.current_user_can_supplier_module('edit'));

CREATE POLICY "suppliers_delete" ON public.suppliers FOR DELETE TO authenticated
    USING (public.current_user_can_supplier_module('delete'));

CREATE POLICY "invoices_select" ON public.supplier_invoices FOR SELECT TO authenticated
    USING (public.current_user_can_supplier_module('view'));

CREATE POLICY "invoices_insert" ON public.supplier_invoices FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_supplier_module('create'));

CREATE POLICY "invoices_update" ON public.supplier_invoices FOR UPDATE TO authenticated
    USING (public.current_user_can_supplier_module('edit'))
    WITH CHECK (public.current_user_can_supplier_module('edit'));

CREATE POLICY "invoices_delete" ON public.supplier_invoices FOR DELETE TO authenticated
    USING (public.current_user_can_supplier_module('delete'));

CREATE POLICY "payments_select" ON public.supplier_payments FOR SELECT TO authenticated
    USING (public.current_user_can_supplier_module('view'));

CREATE POLICY "payments_insert" ON public.supplier_payments FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_supplier_module('create'));

CREATE POLICY "payments_update" ON public.supplier_payments FOR UPDATE TO authenticated
    USING (public.current_user_can_supplier_module('edit'))
    WITH CHECK (public.current_user_can_supplier_module('edit'));

CREATE POLICY "payments_delete" ON public.supplier_payments FOR DELETE TO authenticated
    USING (public.current_user_can_supplier_module('delete'));
