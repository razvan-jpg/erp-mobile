-- Rezervă numărul următor al seriei de factură fiscală, inclusiv pentru casier.

CREATE OR REPLACE FUNCTION public.consume_fiscal_invoice_number(p_series_id uuid)
RETURNS TABLE(serie text, issued_number integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    rec public.document_series%ROWTYPE;
BEGIN
    SELECT * INTO rec
    FROM public.document_series
    WHERE id = p_series_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Serie inexistentă';
    END IF;

    IF rec.company_id IS DISTINCT FROM public.current_user_selected_company_id() THEN
        RAISE EXCEPTION 'Seria nu aparține societății active';
    END IF;

    IF rec.kind <> 'factura_fiscala_casa' OR rec.is_active IS NOT TRUE THEN
        RAISE EXCEPTION 'Seria de factură fiscală nu este activă';
    END IF;

    IF NOT (
        public.is_current_user_superadmin()
        OR public.is_current_user_company_admin()
        OR public.current_user_can_nomenclatoare_module('edit')
        OR EXISTS (
            SELECT 1
            FROM public.user_module_permissions ump
            JOIN public.modules m ON m.id = ump.module_id
            WHERE ump.user_id = auth.uid()
              AND m.code IN ('cashier', 'sales')
              AND m.is_active = true
              AND ump.can_create
        )
    ) THEN
        RAISE EXCEPTION 'Nu aveți dreptul să emiteți factura fiscală';
    END IF;

    UPDATE public.document_series
    SET next_number = rec.next_number + 1
    WHERE id = rec.id;

    serie := rec.serie;
    issued_number := rec.next_number;
    RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.consume_fiscal_invoice_number(uuid) TO authenticated, service_role;
