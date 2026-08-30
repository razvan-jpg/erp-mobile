-- Compensare note de credit / storno cu facturi furnizor deschise

CREATE TABLE public.supplier_invoice_credit_offsets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    credit_invoice_id UUID NOT NULL REFERENCES public.supplier_invoices(id) ON DELETE CASCADE,
    target_invoice_id UUID NOT NULL REFERENCES public.supplier_invoices(id) ON DELETE CASCADE,
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (credit_invoice_id, target_invoice_id),
    CHECK (credit_invoice_id <> target_invoice_id)
);

CREATE INDEX idx_supplier_invoice_credit_offsets_credit
    ON public.supplier_invoice_credit_offsets(credit_invoice_id);
CREATE INDEX idx_supplier_invoice_credit_offsets_target
    ON public.supplier_invoice_credit_offsets(target_invoice_id);
CREATE INDEX idx_supplier_invoice_credit_offsets_company
    ON public.supplier_invoice_credit_offsets(company_id);

ALTER TABLE public.supplier_invoice_credit_offsets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "credit_offsets_select" ON public.supplier_invoice_credit_offsets FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE POLICY "credit_offsets_insert" ON public.supplier_invoice_credit_offsets FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'create', 'create'));

CREATE POLICY "credit_offsets_update" ON public.supplier_invoice_credit_offsets FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'));

CREATE POLICY "credit_offsets_delete" ON public.supplier_invoice_credit_offsets FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete'));

CREATE OR REPLACE FUNCTION public.refresh_invoice_payment_totals(p_invoice_id UUID)
RETURNS VOID AS $$
DECLARE
    v_total NUMERIC(14, 2);
    v_paid NUMERIC(14, 2);
    v_credit_received NUMERIC(14, 2);
    v_credit_applied NUMERIC(14, 2);
    v_effective NUMERIC(14, 2);
    v_status TEXT;
BEGIN
    IF p_invoice_id IS NULL THEN
        RETURN;
    END IF;

    SELECT suma_totala INTO v_total
    FROM public.supplier_invoices WHERE id = p_invoice_id;

    SELECT COALESCE(SUM(suma), 0) INTO v_paid
    FROM public.supplier_payments WHERE invoice_id = p_invoice_id;

    SELECT COALESCE(SUM(amount), 0) INTO v_credit_received
    FROM public.supplier_invoice_credit_offsets WHERE target_invoice_id = p_invoice_id;

    SELECT COALESCE(SUM(amount), 0) INTO v_credit_applied
    FROM public.supplier_invoice_credit_offsets WHERE credit_invoice_id = p_invoice_id;

    IF (SELECT status FROM public.supplier_invoices WHERE id = p_invoice_id) = 'anulata' THEN
        v_status := 'anulata';
        v_effective := 0;
    ELSIF v_total = 0 THEN
        v_status := 'platita';
        v_effective := 0;
    ELSIF v_total < 0 THEN
        v_effective := v_credit_applied;
        IF v_effective >= ABS(v_total) THEN
            v_status := 'platita';
        ELSIF v_effective > 0 THEN
            v_status := 'partial';
        ELSE
            v_status := 'neplatita';
        END IF;
    ELSIF (v_paid + v_credit_received) <= 0 THEN
        v_status := 'neplatita';
        v_effective := v_paid + v_credit_received;
    ELSIF (v_paid + v_credit_received) >= v_total THEN
        v_status := 'platita';
        v_effective := v_paid + v_credit_received;
    ELSE
        v_status := 'partial';
        v_effective := v_paid + v_credit_received;
    END IF;

    IF v_total >= 0 THEN
        UPDATE public.supplier_invoices
        SET suma_platita = v_effective, status = v_status, updated_at = now()
        WHERE id = p_invoice_id;
    ELSE
        UPDATE public.supplier_invoices
        SET suma_platita = v_effective, status = v_status, updated_at = now()
        WHERE id = p_invoice_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.refresh_credit_offset_invoices()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM public.refresh_invoice_payment_totals(OLD.credit_invoice_id);
        PERFORM public.refresh_invoice_payment_totals(OLD.target_invoice_id);
        RETURN OLD;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.credit_invoice_id IS DISTINCT FROM NEW.credit_invoice_id THEN
            PERFORM public.refresh_invoice_payment_totals(OLD.credit_invoice_id);
        END IF;
        IF OLD.target_invoice_id IS DISTINCT FROM NEW.target_invoice_id THEN
            PERFORM public.refresh_invoice_payment_totals(OLD.target_invoice_id);
        END IF;
    END IF;

    PERFORM public.refresh_invoice_payment_totals(NEW.credit_invoice_id);
    PERFORM public.refresh_invoice_payment_totals(NEW.target_invoice_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS supplier_invoice_credit_offsets_refresh ON public.supplier_invoice_credit_offsets;
CREATE TRIGGER supplier_invoice_credit_offsets_refresh
    AFTER INSERT OR UPDATE OR DELETE ON public.supplier_invoice_credit_offsets
    FOR EACH ROW EXECUTE FUNCTION public.refresh_credit_offset_invoices();
