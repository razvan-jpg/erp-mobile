-- Inventar fizic: sesiuni de numărare, diferențe față de stoc scriptic, ajustări la finalizare.

CREATE TABLE public.physical_inventories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    numar_inventar TEXT NOT NULL DEFAULT '',
    data_inventar DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'finalized', 'cancelled')),
    observatii TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    finalized_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, numar_inventar)
);

CREATE TABLE public.physical_inventory_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inventory_id UUID NOT NULL REFERENCES public.physical_inventories(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    stoc_scriptic NUMERIC(14, 4) NOT NULL DEFAULT 0,
    cantitate_numarata NUMERIC(14, 4),
    unitate_masura TEXT NOT NULL DEFAULT 'buc',
    observatii TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (inventory_id, product_id),
    CHECK (cantitate_numarata IS NULL OR cantitate_numarata >= 0)
);

ALTER TABLE public.stock_movements
    ADD COLUMN IF NOT EXISTS physical_inventory_id UUID REFERENCES public.physical_inventories(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS physical_inventory_line_id UUID REFERENCES public.physical_inventory_lines(id) ON DELETE SET NULL;

CREATE INDEX idx_physical_inventories_company ON public.physical_inventories(company_id);
CREATE INDEX idx_physical_inventories_status ON public.physical_inventories(company_id, status);
CREATE INDEX idx_physical_inventories_data ON public.physical_inventories(data_inventar DESC);
CREATE INDEX idx_physical_inventory_lines_inventory ON public.physical_inventory_lines(inventory_id);
CREATE INDEX idx_physical_inventory_lines_product ON public.physical_inventory_lines(product_id);
CREATE INDEX idx_stock_movements_physical_inventory ON public.stock_movements(physical_inventory_id);

CREATE TRIGGER physical_inventories_updated_at
    BEFORE UPDATE ON public.physical_inventories
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER physical_inventory_lines_updated_at
    BEFORE UPDATE ON public.physical_inventory_lines
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.assign_physical_inventory_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_year INT;
    v_next INT;
BEGIN
    IF NEW.numar_inventar IS NOT NULL AND btrim(NEW.numar_inventar) <> '' THEN
        RETURN NEW;
    END IF;

    v_year := EXTRACT(YEAR FROM NEW.data_inventar)::INT;

    SELECT COALESCE(MAX(
        CASE
            WHEN numar_inventar ~ ('^[0-9]+/' || v_year::TEXT || '$')
                THEN split_part(numar_inventar, '/', 1)::INT
            ELSE 0
        END
    ), 0) + 1
    INTO v_next
    FROM public.physical_inventories
    WHERE company_id = NEW.company_id;

    NEW.numar_inventar := v_next::TEXT || '/' || v_year::TEXT;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS physical_inventories_assign_number ON public.physical_inventories;
CREATE TRIGGER physical_inventories_assign_number
    BEFORE INSERT ON public.physical_inventories
    FOR EACH ROW EXECUTE FUNCTION public.assign_physical_inventory_number();

CREATE OR REPLACE FUNCTION public.populate_physical_inventory_from_stock(p_inventory_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_inserted INT;
BEGIN
    SELECT company_id
    INTO v_company_id
    FROM public.physical_inventories
    WHERE id = p_inventory_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'INVENTORY_NOT_FOUND';
    END IF;

    IF NOT public.current_user_can_access_selected_company_inventory_data(v_company_id, 'edit', 'edit') THEN
        RAISE EXCEPTION 'INVENTORY_EDIT_FORBIDDEN';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.physical_inventories
        WHERE id = p_inventory_id AND status = 'open'
    ) THEN
        RAISE EXCEPTION 'INVENTORY_NOT_OPEN';
    END IF;

    INSERT INTO public.physical_inventory_lines (
        inventory_id,
        company_id,
        product_id,
        stoc_scriptic,
        unitate_masura
    )
    SELECT
        p_inventory_id,
        ps.company_id,
        ps.product_id,
        ps.cantitate,
        COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc')
    FROM public.product_stocks ps
    JOIN public.products p ON p.id = ps.product_id
    WHERE ps.company_id = v_company_id
    ON CONFLICT (inventory_id, product_id) DO NOTHING;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_physical_inventory_line(
    p_inventory_id UUID,
    p_product_id UUID,
    p_cantitate_numarata NUMERIC,
    p_observatii TEXT DEFAULT NULL
)
RETURNS public.physical_inventory_lines
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inventory RECORD;
    v_product RECORD;
    v_stock NUMERIC(14, 4) := 0;
    v_line public.physical_inventory_lines;
BEGIN
    SELECT *
    INTO v_inventory
    FROM public.physical_inventories
    WHERE id = p_inventory_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVENTORY_NOT_FOUND';
    END IF;

    IF v_inventory.status <> 'open' THEN
        RAISE EXCEPTION 'INVENTORY_NOT_OPEN';
    END IF;

    IF NOT public.current_user_can_access_selected_company_inventory_data(v_inventory.company_id, 'edit', 'edit') THEN
        RAISE EXCEPTION 'INVENTORY_EDIT_FORBIDDEN';
    END IF;

    SELECT id, company_id, unitate_masura
    INTO v_product
    FROM public.products
    WHERE id = p_product_id
      AND company_id = v_inventory.company_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PRODUCT_NOT_FOUND';
    END IF;

    IF p_cantitate_numarata IS NULL OR p_cantitate_numarata < 0 THEN
        RAISE EXCEPTION 'INVALID_COUNTED_QUANTITY';
    END IF;

    SELECT cantitate
    INTO v_stock
    FROM public.product_stocks
    WHERE company_id = v_inventory.company_id
      AND product_id = p_product_id;

    v_stock := COALESCE(v_stock, 0);

    INSERT INTO public.physical_inventory_lines (
        inventory_id,
        company_id,
        product_id,
        stoc_scriptic,
        cantitate_numarata,
        unitate_masura,
        observatii
    ) VALUES (
        p_inventory_id,
        v_inventory.company_id,
        p_product_id,
        v_stock,
        p_cantitate_numarata,
        COALESCE(NULLIF(btrim(v_product.unitate_masura), ''), 'buc'),
        NULLIF(btrim(p_observatii), '')
    )
    ON CONFLICT (inventory_id, product_id) DO UPDATE
        SET cantitate_numarata = EXCLUDED.cantitate_numarata,
            observatii = COALESCE(EXCLUDED.observatii, public.physical_inventory_lines.observatii),
            updated_at = now()
    RETURNING * INTO v_line;

    RETURN v_line;
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_physical_inventory(p_inventory_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inventory RECORD;
    v_line RECORD;
    v_delta NUMERIC(14, 4);
    v_tip TEXT;
    v_qty NUMERIC(14, 4);
BEGIN
    SELECT *
    INTO v_inventory
    FROM public.physical_inventories
    WHERE id = p_inventory_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVENTORY_NOT_FOUND';
    END IF;

    IF v_inventory.status <> 'open' THEN
        RAISE EXCEPTION 'INVENTORY_NOT_OPEN';
    END IF;

    IF NOT public.current_user_can_access_selected_company_inventory_data(v_inventory.company_id, 'edit', 'edit') THEN
        RAISE EXCEPTION 'INVENTORY_FINALIZE_FORBIDDEN';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.physical_inventory_lines
        WHERE inventory_id = p_inventory_id
          AND cantitate_numarata IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'INVENTORY_NO_COUNTED_LINES';
    END IF;

    FOR v_line IN
        SELECT *
        FROM public.physical_inventory_lines
        WHERE inventory_id = p_inventory_id
          AND cantitate_numarata IS NOT NULL
    LOOP
        v_delta := v_line.cantitate_numarata - v_line.stoc_scriptic;
        IF v_delta = 0 THEN
            CONTINUE;
        END IF;

        IF v_delta > 0 THEN
            v_tip := 'intrare';
            v_qty := v_delta;
        ELSE
            v_tip := 'iesire';
            v_qty := ABS(v_delta);
        END IF;

        INSERT INTO public.stock_movements (
            company_id,
            product_id,
            tip,
            cantitate,
            unitate_masura,
            sursa,
            referinta,
            data_tranzactie,
            physical_inventory_id,
            physical_inventory_line_id
        ) VALUES (
            v_line.company_id,
            v_line.product_id,
            v_tip,
            v_qty,
            v_line.unitate_masura,
            'physical_inventory',
            'Inventar ' || v_inventory.numar_inventar,
            v_inventory.data_inventar,
            p_inventory_id,
            v_line.id
        );

        INSERT INTO public.product_stocks (company_id, product_id, cantitate)
        VALUES (v_line.company_id, v_line.product_id, 0)
        ON CONFLICT (company_id, product_id) DO NOTHING;

        IF v_tip = 'intrare' THEN
            UPDATE public.product_stocks
            SET cantitate = cantitate + v_qty,
                updated_at = now()
            WHERE company_id = v_line.company_id
              AND product_id = v_line.product_id;
        ELSE
            UPDATE public.product_stocks
            SET cantitate = cantitate - v_qty,
                updated_at = now()
            WHERE company_id = v_line.company_id
              AND product_id = v_line.product_id;
        END IF;
    END LOOP;

    UPDATE public.physical_inventories
    SET status = 'finalized',
        finalized_at = now(),
        updated_at = now()
    WHERE id = p_inventory_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_physical_inventory(p_inventory_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_status TEXT;
BEGIN
    SELECT company_id, status
    INTO v_company_id, v_status
    FROM public.physical_inventories
    WHERE id = p_inventory_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'INVENTORY_NOT_FOUND';
    END IF;

    IF NOT public.current_user_can_access_selected_company_inventory_data(v_company_id, 'delete', 'delete') THEN
        RAISE EXCEPTION 'INVENTORY_DELETE_FORBIDDEN';
    END IF;

    IF v_status <> 'open' THEN
        RAISE EXCEPTION 'INVENTORY_NOT_OPEN';
    END IF;

    DELETE FROM public.physical_inventories
    WHERE id = p_inventory_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.populate_physical_inventory_from_stock(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_physical_inventory_line(UUID, UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_physical_inventory(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_physical_inventory(UUID) TO authenticated;

ALTER TABLE public.physical_inventories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.physical_inventory_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "physical_inventories_select" ON public.physical_inventories FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'view', 'view'));

CREATE POLICY "physical_inventories_insert" ON public.physical_inventories FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_inventory_data(company_id, 'create', 'create'));

CREATE POLICY "physical_inventories_update" ON public.physical_inventories FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_inventory_data(company_id, 'edit', 'edit'));

CREATE POLICY "physical_inventories_delete" ON public.physical_inventories FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'delete', 'delete'));

CREATE POLICY "physical_inventory_lines_select" ON public.physical_inventory_lines FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'view', 'view'));

CREATE POLICY "physical_inventory_lines_insert" ON public.physical_inventory_lines FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_inventory_data(company_id, 'create', 'create'));

CREATE POLICY "physical_inventory_lines_update" ON public.physical_inventory_lines FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_inventory_data(company_id, 'edit', 'edit'));

CREATE POLICY "physical_inventory_lines_delete" ON public.physical_inventory_lines FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_inventory_data(company_id, 'delete', 'delete'));

UPDATE public.modules
SET description = 'Gestionare stocuri, mișcări și inventar fizic.'
WHERE code = 'inventory';
