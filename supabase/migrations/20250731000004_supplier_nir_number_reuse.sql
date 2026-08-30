-- Refolosește numerele NIR șterse (prioritar aceeași factură) și umple golurile din serie.

CREATE TABLE public.supplier_nir_released_numbers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES public.supplier_invoices(id) ON DELETE CASCADE,
    numar_nir TEXT NOT NULL,
    released_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, numar_nir)
);

CREATE UNIQUE INDEX idx_supplier_nir_released_invoice
    ON public.supplier_nir_released_numbers(company_id, invoice_id)
    WHERE invoice_id IS NOT NULL;

CREATE INDEX idx_supplier_nir_released_company
    ON public.supplier_nir_released_numbers(company_id, released_at);

ALTER TABLE public.supplier_nir_released_numbers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supplier_nir_released_numbers_select" ON public.supplier_nir_released_numbers
    FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE OR REPLACE FUNCTION public.release_supplier_nir_number(
    p_company_id UUID,
    p_invoice_id UUID,
    p_numar_nir TEXT,
    p_reserve_for_invoice BOOLEAN DEFAULT true
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_numar_nir TEXT := btrim(COALESCE(p_numar_nir, ''));
BEGIN
    IF v_numar_nir = '' THEN
        RETURN;
    END IF;

    IF p_reserve_for_invoice AND p_invoice_id IS NOT NULL THEN
        DELETE FROM public.supplier_nir_released_numbers
        WHERE company_id = p_company_id
          AND invoice_id = p_invoice_id;
    END IF;

    INSERT INTO public.supplier_nir_released_numbers (company_id, invoice_id, numar_nir)
    VALUES (
        p_company_id,
        CASE WHEN p_reserve_for_invoice THEN p_invoice_id ELSE NULL END,
        v_numar_nir
    )
    ON CONFLICT (company_id, numar_nir) DO UPDATE
        SET invoice_id = EXCLUDED.invoice_id,
            released_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_supplier_nir_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_year INT;
    v_next INT;
    v_reserved TEXT;
    v_max_used INT;
    v_max_released INT;
BEGIN
    IF NEW.numar_nir IS NOT NULL AND btrim(NEW.numar_nir) <> '' THEN
        RETURN NEW;
    END IF;

    v_year := EXTRACT(YEAR FROM NEW.data_nir)::INT;

    SELECT numar_nir
    INTO v_reserved
    FROM public.supplier_nir_released_numbers
    WHERE company_id = NEW.company_id
      AND invoice_id = NEW.invoice_id
    LIMIT 1;

    IF v_reserved IS NOT NULL THEN
        NEW.numar_nir := v_reserved;
        DELETE FROM public.supplier_nir_released_numbers
        WHERE company_id = NEW.company_id
          AND numar_nir = v_reserved;
        RETURN NEW;
    END IF;

    SELECT numar_nir
    INTO v_reserved
    FROM public.supplier_nir_released_numbers
    WHERE company_id = NEW.company_id
      AND invoice_id IS NULL
      AND numar_nir ~ ('^[0-9]+/' || v_year::TEXT || '$')
    ORDER BY split_part(numar_nir, '/', 1)::INT
    LIMIT 1;

    IF v_reserved IS NOT NULL THEN
        NEW.numar_nir := v_reserved;
        DELETE FROM public.supplier_nir_released_numbers
        WHERE company_id = NEW.company_id
          AND numar_nir = v_reserved;
        RETURN NEW;
    END IF;

    SELECT COALESCE(MAX(
        CASE
            WHEN numar_nir ~ ('^[0-9]+/' || v_year::TEXT || '$')
                THEN split_part(numar_nir, '/', 1)::INT
            ELSE 0
        END
    ), 0)
    INTO v_max_used
    FROM public.supplier_nirs
    WHERE company_id = NEW.company_id;

    SELECT COALESCE(MAX(split_part(numar_nir, '/', 1)::INT), 0)
    INTO v_max_released
    FROM public.supplier_nir_released_numbers
    WHERE company_id = NEW.company_id
      AND numar_nir ~ ('^[0-9]+/' || v_year::TEXT || '$');

    SELECT MIN(candidate.n)
    INTO v_next
    FROM generate_series(1, GREATEST(v_max_used, v_max_released) + 1) AS candidate(n)
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.supplier_nirs sn
        WHERE sn.company_id = NEW.company_id
          AND sn.numar_nir = candidate.n::TEXT || '/' || v_year::TEXT
    )
      AND NOT EXISTS (
        SELECT 1
        FROM public.supplier_nir_released_numbers rn
        WHERE rn.company_id = NEW.company_id
          AND rn.numar_nir = candidate.n::TEXT || '/' || v_year::TEXT
      );

    IF v_next IS NULL THEN
        v_next := GREATEST(v_max_used, v_max_released) + 1;
    END IF;

    NEW.numar_nir := v_next::TEXT || '/' || v_year::TEXT;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_supplier_nir(p_nir_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_invoice_id UUID;
    v_numar_nir TEXT;
    v_can_delete BOOLEAN := false;
BEGIN
    SELECT company_id, invoice_id, numar_nir
    INTO v_company_id, v_invoice_id, v_numar_nir
    FROM public.supplier_nirs
    WHERE id = p_nir_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'NIR_NOT_FOUND';
    END IF;

    v_can_delete := public.is_current_user_superadmin()
        OR (
            public.is_current_user_company_admin()
            AND public.current_user_has_company_access(v_company_id, 'delete')
        )
        OR public.current_user_can_access_selected_company_data(v_company_id, 'delete', 'delete');

    IF NOT v_can_delete THEN
        RAISE EXCEPTION 'NIR_DELETE_FORBIDDEN';
    END IF;

    PERFORM public.release_supplier_nir_number(
        v_company_id,
        v_invoice_id,
        v_numar_nir,
        true
    );

    DELETE FROM public.supplier_nirs
    WHERE id = p_nir_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NIR_NOT_FOUND';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_supplier_invoice(p_invoice_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_can_delete BOOLEAN := false;
    v_nir RECORD;
BEGIN
    SELECT company_id
    INTO v_company_id
    FROM public.supplier_invoices
    WHERE id = p_invoice_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'INVOICE_NOT_FOUND';
    END IF;

    v_can_delete := public.is_current_user_superadmin()
        OR (
            public.is_current_user_company_admin()
            AND public.current_user_has_company_access(v_company_id, 'delete')
        )
        OR public.current_user_can_access_selected_company_data(v_company_id, 'delete', 'delete');

    IF NOT v_can_delete THEN
        RAISE EXCEPTION 'INVOICE_DELETE_FORBIDDEN';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.supplier_payments
        WHERE invoice_id = p_invoice_id
    ) THEN
        RAISE EXCEPTION 'INVOICE_HAS_PAYMENTS';
    END IF;

    FOR v_nir IN
        SELECT company_id, numar_nir
        FROM public.supplier_nirs
        WHERE invoice_id = p_invoice_id
    LOOP
        PERFORM public.release_supplier_nir_number(
            v_nir.company_id,
            NULL,
            v_nir.numar_nir,
            false
        );
    END LOOP;

    DELETE FROM public.supplier_nirs
    WHERE invoice_id = p_invoice_id;

    DELETE FROM public.supplier_invoice_lines
    WHERE invoice_id = p_invoice_id;

    DELETE FROM public.supplier_invoices
    WHERE id = p_invoice_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVOICE_NOT_FOUND';
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.release_supplier_nir_number(UUID, UUID, TEXT, BOOLEAN) TO authenticated;
