-- Mai multe NIR-uri pe factură, stoc pe gestiune, bon de transfer, inventar pe gestiune
-- și proces-verbal de diferențe.

CREATE TABLE IF NOT EXISTS public.warehouse_product_stocks (
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES public.company_warehouses(id) ON DELETE RESTRICT,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    cantitate NUMERIC(14, 4) NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (company_id, warehouse_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_warehouse_product_stocks_company
    ON public.warehouse_product_stocks(company_id, warehouse_id);

DROP TRIGGER IF EXISTS warehouse_product_stocks_updated_at ON public.warehouse_product_stocks;
CREATE TRIGGER warehouse_product_stocks_updated_at
    BEFORE UPDATE ON public.warehouse_product_stocks
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.apply_warehouse_stock_delta(
    p_company_id UUID,
    p_warehouse_id UUID,
    p_product_id UUID,
    p_delta NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_warehouse_id IS NULL OR p_delta = 0 THEN
        RETURN;
    END IF;

    INSERT INTO public.warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    VALUES (p_company_id, p_warehouse_id, p_product_id, p_delta)
    ON CONFLICT (company_id, warehouse_id, product_id) DO UPDATE
        SET cantitate = public.warehouse_product_stocks.cantitate + EXCLUDED.cantitate,
            updated_at = now();
END;
$$;

INSERT INTO public.warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
SELECT
    sm.company_id,
    sm.warehouse_id,
    sm.product_id,
    SUM(CASE WHEN sm.tip = 'intrare' THEN sm.cantitate ELSE -sm.cantitate END)
FROM public.stock_movements sm
WHERE sm.warehouse_id IS NOT NULL
GROUP BY sm.company_id, sm.warehouse_id, sm.product_id
ON CONFLICT (company_id, warehouse_id, product_id) DO UPDATE
    SET cantitate = EXCLUDED.cantitate,
        updated_at = now();

CREATE OR REPLACE FUNCTION public.sync_warehouse_stock_from_movement()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_old NUMERIC(14, 4);
    v_new NUMERIC(14, 4);
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_new := CASE WHEN NEW.tip = 'intrare' THEN NEW.cantitate ELSE -NEW.cantitate END;
        PERFORM public.apply_warehouse_stock_delta(NEW.company_id, NEW.warehouse_id, NEW.product_id, v_new);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        v_old := CASE WHEN OLD.tip = 'intrare' THEN -OLD.cantitate ELSE OLD.cantitate END;
        PERFORM public.apply_warehouse_stock_delta(OLD.company_id, OLD.warehouse_id, OLD.product_id, v_old);
        RETURN OLD;
    END IF;

    v_old := CASE WHEN OLD.tip = 'intrare' THEN OLD.cantitate ELSE -OLD.cantitate END;
    v_new := CASE WHEN NEW.tip = 'intrare' THEN NEW.cantitate ELSE -NEW.cantitate END;

    IF OLD.warehouse_id IS NOT DISTINCT FROM NEW.warehouse_id
       AND OLD.product_id IS NOT DISTINCT FROM NEW.product_id
       AND OLD.company_id IS NOT DISTINCT FROM NEW.company_id THEN
        PERFORM public.apply_warehouse_stock_delta(NEW.company_id, NEW.warehouse_id, NEW.product_id, v_new - v_old);
    ELSE
        PERFORM public.apply_warehouse_stock_delta(OLD.company_id, OLD.warehouse_id, OLD.product_id, -v_old);
        PERFORM public.apply_warehouse_stock_delta(NEW.company_id, NEW.warehouse_id, NEW.product_id, v_new);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS stock_movements_sync_warehouse_stock ON public.stock_movements;
CREATE TRIGGER stock_movements_sync_warehouse_stock
    AFTER INSERT OR UPDATE OR DELETE ON public.stock_movements
    FOR EACH ROW EXECUTE FUNCTION public.sync_warehouse_stock_from_movement();

ALTER TABLE public.supplier_nirs DROP CONSTRAINT IF EXISTS supplier_nirs_invoice_id_key;

CREATE OR REPLACE FUNCTION public.move_supplier_nir_warehouse_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.warehouse_id IS NOT DISTINCT FROM OLD.warehouse_id THEN
        RETURN NEW;
    END IF;

    UPDATE public.stock_movements
    SET warehouse_id = NEW.warehouse_id
    WHERE nir_id = NEW.id
      AND warehouse_id IS NOT DISTINCT FROM OLD.warehouse_id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS supplier_nirs_move_warehouse_stock ON public.supplier_nirs;
CREATE TRIGGER supplier_nirs_move_warehouse_stock
    AFTER UPDATE OF warehouse_id ON public.supplier_nirs
    FOR EACH ROW EXECUTE FUNCTION public.move_supplier_nir_warehouse_stock();

CREATE OR REPLACE FUNCTION public.warehouse_stock_quantity(
    p_company_id UUID,
    p_warehouse_id UUID,
    p_product_id UUID
)
RETURNS NUMERIC
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE((
        SELECT wps.cantitate
        FROM public.warehouse_product_stocks wps
        WHERE wps.company_id = p_company_id
          AND wps.warehouse_id = p_warehouse_id
          AND wps.product_id = p_product_id
    ), 0);
$$;

-- Bon de transfer între gestiuni.

CREATE TABLE IF NOT EXISTS public.stock_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    numar TEXT NOT NULL DEFAULT '',
    data_bon DATE NOT NULL DEFAULT CURRENT_DATE,
    source_warehouse_id UUID NOT NULL REFERENCES public.company_warehouses(id) ON DELETE RESTRICT,
    destination_warehouse_id UUID NOT NULL REFERENCES public.company_warehouses(id) ON DELETE RESTRICT,
    observatii TEXT,
    created_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, numar),
    CHECK (source_warehouse_id <> destination_warehouse_id)
);

CREATE TABLE IF NOT EXISTS public.stock_transfer_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transfer_id UUID NOT NULL REFERENCES public.stock_transfers(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    numar_linie INTEGER NOT NULL,
    cantitate NUMERIC(14, 4) NOT NULL CHECK (cantitate > 0),
    unitate_masura TEXT NOT NULL DEFAULT 'buc',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (transfer_id, numar_linie),
    UNIQUE (transfer_id, product_id)
);

ALTER TABLE public.stock_movements
    ADD COLUMN IF NOT EXISTS transfer_id UUID REFERENCES public.stock_transfers(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_stock_transfers_company ON public.stock_transfers(company_id, data_bon DESC);
CREATE INDEX IF NOT EXISTS idx_stock_transfer_lines_transfer ON public.stock_transfer_lines(transfer_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_transfer ON public.stock_movements(transfer_id);

DROP TRIGGER IF EXISTS stock_transfers_updated_at ON public.stock_transfers;
CREATE TRIGGER stock_transfers_updated_at
    BEFORE UPDATE ON public.stock_transfers
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.assign_stock_transfer_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_year INT;
    v_next INT;
BEGIN
    IF NEW.numar IS NOT NULL AND btrim(NEW.numar) <> '' THEN
        RETURN NEW;
    END IF;

    v_year := EXTRACT(YEAR FROM NEW.data_bon)::INT;

    SELECT COALESCE(MAX(
        CASE
            WHEN numar ~ ('^[0-9]+/' || v_year::TEXT || '$')
                THEN split_part(numar, '/', 1)::INT
            ELSE 0
        END
    ), 0) + 1
    INTO v_next
    FROM public.stock_transfers
    WHERE company_id = NEW.company_id;

    NEW.numar := v_next::TEXT || '/' || v_year::TEXT;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS stock_transfers_assign_number ON public.stock_transfers;
CREATE TRIGGER stock_transfers_assign_number
    BEFORE INSERT ON public.stock_transfers
    FOR EACH ROW EXECUTE FUNCTION public.assign_stock_transfer_number();

CREATE OR REPLACE FUNCTION public.post_stock_transfer(
    p_company_id UUID,
    p_data_bon DATE,
    p_source_warehouse_id UUID,
    p_destination_warehouse_id UUID,
    p_observatii TEXT,
    p_lines JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_transfer_id UUID;
    v_line JSONB;
    v_product_id UUID;
    v_qty NUMERIC(14, 4);
    v_unit TEXT;
    v_tip TEXT;
    v_available NUMERIC(14, 4);
    v_index INT := 0;
    v_numar TEXT;
BEGIN
    IF NOT private.current_user_can_access_selected_company_inventory_data(p_company_id, 'create'::text, 'create'::text) THEN
        RAISE EXCEPTION 'TRANSFER_FORBIDDEN';
    END IF;

    IF p_source_warehouse_id = p_destination_warehouse_id THEN
        RAISE EXCEPTION 'TRANSFER_SAME_WAREHOUSE';
    END IF;

    IF p_lines IS NULL OR jsonb_array_length(p_lines) = 0 THEN
        RAISE EXCEPTION 'TRANSFER_NO_LINES';
    END IF;

    INSERT INTO public.stock_transfers (
        company_id, data_bon, source_warehouse_id, destination_warehouse_id, observatii, created_by
    ) VALUES (
        p_company_id,
        COALESCE(p_data_bon, CURRENT_DATE),
        p_source_warehouse_id,
        p_destination_warehouse_id,
        NULLIF(btrim(p_observatii), ''),
        auth.uid()
    )
    RETURNING id, numar INTO v_transfer_id, v_numar;

    FOR v_line IN SELECT value FROM jsonb_array_elements(p_lines)
    LOOP
        v_index := v_index + 1;
        v_product_id := (v_line->>'product_id')::UUID;
        v_qty := (v_line->>'cantitate')::NUMERIC;

        IF v_qty IS NULL OR v_qty <= 0 THEN
            RAISE EXCEPTION 'TRANSFER_INVALID_QUANTITY';
        END IF;

        SELECT p.tip, COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc')
        INTO v_tip, v_unit
        FROM public.products p
        WHERE p.id = v_product_id
          AND p.company_id = p_company_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'TRANSFER_PRODUCT_NOT_FOUND';
        END IF;

        IF v_tip NOT IN ('materie_prima', 'marfa', 'ambalaj', 'materiale_consumabile') THEN
            RAISE EXCEPTION 'TRANSFER_PRODUCT_NOT_ALLOWED';
        END IF;

        v_available := public.warehouse_stock_quantity(p_company_id, p_source_warehouse_id, v_product_id);
        IF v_available < v_qty THEN
            RAISE EXCEPTION 'TRANSFER_INSUFFICIENT_STOCK';
        END IF;

        INSERT INTO public.stock_transfer_lines (
            transfer_id, company_id, product_id, numar_linie, cantitate, unitate_masura
        ) VALUES (
            v_transfer_id, p_company_id, v_product_id, v_index, v_qty, v_unit
        );

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, transfer_id, referinta, data_tranzactie
        ) VALUES (
            p_company_id, v_product_id, 'iesire', v_qty, v_unit, 'stock_transfer',
            p_source_warehouse_id, v_transfer_id, 'BT ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE)
        );

        INSERT INTO public.stock_movements (
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            warehouse_id, transfer_id, referinta, data_tranzactie
        ) VALUES (
            p_company_id, v_product_id, 'intrare', v_qty, v_unit, 'stock_transfer',
            p_destination_warehouse_id, v_transfer_id, 'BT ' || v_numar, COALESCE(p_data_bon, CURRENT_DATE)
        );
    END LOOP;

    RETURN v_transfer_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_stock_transfer(p_transfer_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
BEGIN
    SELECT company_id INTO v_company_id
    FROM public.stock_transfers
    WHERE id = p_transfer_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'TRANSFER_NOT_FOUND';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_company_id, 'delete'::text, 'delete'::text) THEN
        RAISE EXCEPTION 'TRANSFER_DELETE_FORBIDDEN';
    END IF;

    DELETE FROM public.stock_transfers WHERE id = p_transfer_id;
END;
$$;

-- Inventar pe gestiune + proces-verbal de diferențe.

ALTER TABLE public.physical_inventories
    ADD COLUMN IF NOT EXISTS warehouse_id UUID REFERENCES public.company_warehouses(id) ON DELETE RESTRICT;

CREATE INDEX IF NOT EXISTS idx_physical_inventories_warehouse
    ON public.physical_inventories(warehouse_id);

CREATE TABLE IF NOT EXISTS public.inventory_difference_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    inventory_id UUID NOT NULL UNIQUE REFERENCES public.physical_inventories(id) ON DELETE CASCADE,
    warehouse_id UUID REFERENCES public.company_warehouses(id) ON DELETE RESTRICT,
    numar TEXT NOT NULL,
    data_ora TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.inventory_difference_report_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES public.inventory_difference_reports(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    denumire TEXT NOT NULL,
    unitate_masura TEXT NOT NULL DEFAULT 'buc',
    stoc_scriptic NUMERIC(14, 4) NOT NULL,
    cantitate_faptica NUMERIC(14, 4) NOT NULL,
    diferenta NUMERIC(14, 4) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_inventory_difference_reports_company
    ON public.inventory_difference_reports(company_id, data_ora DESC);
CREATE INDEX IF NOT EXISTS idx_inventory_difference_report_lines_report
    ON public.inventory_difference_report_lines(report_id);

DROP FUNCTION IF EXISTS public.populate_physical_inventory_from_stock(UUID);

CREATE OR REPLACE FUNCTION public.populate_physical_inventory_from_stock(p_inventory_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_company_id UUID;
    v_warehouse_id UUID;
    v_inserted INT;
BEGIN
    SELECT company_id, warehouse_id
    INTO v_company_id, v_warehouse_id
    FROM public.physical_inventories
    WHERE id = p_inventory_id;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'INVENTORY_NOT_FOUND';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_company_id, 'edit'::text, 'edit'::text) THEN
        RAISE EXCEPTION 'INVENTORY_EDIT_FORBIDDEN';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.physical_inventories
        WHERE id = p_inventory_id AND status = 'open'
    ) THEN
        RAISE EXCEPTION 'INVENTORY_NOT_OPEN';
    END IF;

    IF v_warehouse_id IS NULL THEN
        INSERT INTO public.physical_inventory_lines (
            inventory_id, company_id, product_id, stoc_scriptic, unitate_masura
        )
        SELECT
            p_inventory_id, ps.company_id, ps.product_id, ps.cantitate,
            COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc')
        FROM public.product_stocks ps
        JOIN public.products p ON p.id = ps.product_id
        WHERE ps.company_id = v_company_id
        ON CONFLICT (inventory_id, product_id) DO UPDATE
            SET stoc_scriptic = EXCLUDED.stoc_scriptic,
                updated_at = now();
    ELSE
        INSERT INTO public.physical_inventory_lines (
            inventory_id, company_id, product_id, stoc_scriptic, unitate_masura
        )
        SELECT
            p_inventory_id, wps.company_id, wps.product_id, wps.cantitate,
            COALESCE(NULLIF(btrim(p.unitate_masura), ''), 'buc')
        FROM public.warehouse_product_stocks wps
        JOIN public.products p ON p.id = wps.product_id
        WHERE wps.company_id = v_company_id
          AND wps.warehouse_id = v_warehouse_id
        ON CONFLICT (inventory_id, product_id) DO UPDATE
            SET stoc_scriptic = EXCLUDED.stoc_scriptic,
                updated_at = now();
    END IF;

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
    SELECT * INTO v_inventory
    FROM public.physical_inventories
    WHERE id = p_inventory_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVENTORY_NOT_FOUND';
    END IF;

    IF v_inventory.status <> 'open' THEN
        RAISE EXCEPTION 'INVENTORY_NOT_OPEN';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_inventory.company_id, 'edit'::text, 'edit'::text) THEN
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

    IF v_inventory.warehouse_id IS NULL THEN
        SELECT cantitate INTO v_stock
        FROM public.product_stocks
        WHERE company_id = v_inventory.company_id
          AND product_id = p_product_id;
    ELSE
        v_stock := public.warehouse_stock_quantity(v_inventory.company_id, v_inventory.warehouse_id, p_product_id);
    END IF;

    v_stock := COALESCE(v_stock, 0);

    INSERT INTO public.physical_inventory_lines (
        inventory_id, company_id, product_id, stoc_scriptic, cantitate_numarata, unitate_masura, observatii
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
            stoc_scriptic = EXCLUDED.stoc_scriptic,
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
    v_scriptic NUMERIC(14, 4);
    v_posted_at TIMESTAMPTZ;
    v_posted_date DATE;
    v_report_id UUID;
    v_year INT;
    v_next INT;
    v_numar TEXT;
BEGIN
    SELECT * INTO v_inventory
    FROM public.physical_inventories
    WHERE id = p_inventory_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVENTORY_NOT_FOUND';
    END IF;

    IF v_inventory.status <> 'open' THEN
        RAISE EXCEPTION 'INVENTORY_NOT_OPEN';
    END IF;

    IF NOT private.current_user_can_access_selected_company_inventory_data(v_inventory.company_id, 'edit'::text, 'edit'::text) THEN
        RAISE EXCEPTION 'INVENTORY_FINALIZE_FORBIDDEN';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.physical_inventory_lines
        WHERE inventory_id = p_inventory_id
          AND cantitate_numarata IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'INVENTORY_NO_COUNTED_LINES';
    END IF;

    v_posted_at := now();
    v_posted_date := (v_posted_at AT TIME ZONE 'Europe/Bucharest')::DATE;

    FOR v_line IN
        SELECT * FROM public.physical_inventory_lines
        WHERE inventory_id = p_inventory_id
          AND cantitate_numarata IS NOT NULL
    LOOP
        IF v_inventory.warehouse_id IS NULL THEN
            SELECT COALESCE(cantitate, 0) INTO v_scriptic
            FROM public.product_stocks
            WHERE company_id = v_line.company_id
              AND product_id = v_line.product_id;
            v_scriptic := COALESCE(v_scriptic, 0);
        ELSE
            v_scriptic := public.warehouse_stock_quantity(
                v_line.company_id, v_inventory.warehouse_id, v_line.product_id
            );
        END IF;

        UPDATE public.physical_inventory_lines
        SET stoc_scriptic = v_scriptic,
            updated_at = v_posted_at
        WHERE id = v_line.id;

        v_delta := v_line.cantitate_numarata - v_scriptic;
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
            company_id, product_id, tip, cantitate, unitate_masura, sursa,
            referinta, data_tranzactie, warehouse_id, physical_inventory_id, physical_inventory_line_id
        ) VALUES (
            v_line.company_id, v_line.product_id, v_tip, v_qty, v_line.unitate_masura,
            'physical_inventory',
            'Inventar ' || v_inventory.numar_inventar,
            v_posted_date,
            v_inventory.warehouse_id,
            p_inventory_id,
            v_line.id
        );

        INSERT INTO public.product_stocks (company_id, product_id, cantitate)
        VALUES (v_line.company_id, v_line.product_id, 0)
        ON CONFLICT (company_id, product_id) DO NOTHING;

        IF v_tip = 'intrare' THEN
            UPDATE public.product_stocks
            SET cantitate = cantitate + v_qty, updated_at = v_posted_at
            WHERE company_id = v_line.company_id AND product_id = v_line.product_id;
        ELSE
            UPDATE public.product_stocks
            SET cantitate = cantitate - v_qty, updated_at = v_posted_at
            WHERE company_id = v_line.company_id AND product_id = v_line.product_id;
        END IF;
    END LOOP;

    IF EXISTS (
        SELECT 1 FROM public.physical_inventory_lines
        WHERE inventory_id = p_inventory_id
          AND cantitate_numarata IS NOT NULL
          AND cantitate_numarata <> stoc_scriptic
    ) THEN
        v_year := EXTRACT(YEAR FROM v_posted_date)::INT;
        SELECT COALESCE(MAX(
            CASE
                WHEN numar ~ ('^[0-9]+/' || v_year::TEXT || '$')
                    THEN split_part(numar, '/', 1)::INT
                ELSE 0
            END
        ), 0) + 1
        INTO v_next
        FROM public.inventory_difference_reports
        WHERE company_id = v_inventory.company_id;

        v_numar := v_next::TEXT || '/' || v_year::TEXT;

        INSERT INTO public.inventory_difference_reports (
            company_id, inventory_id, warehouse_id, numar, data_ora
        ) VALUES (
            v_inventory.company_id, p_inventory_id, v_inventory.warehouse_id, v_numar, v_posted_at
        )
        RETURNING id INTO v_report_id;

        INSERT INTO public.inventory_difference_report_lines (
            report_id, company_id, product_id, denumire, unitate_masura,
            stoc_scriptic, cantitate_faptica, diferenta
        )
        SELECT
            v_report_id,
            l.company_id,
            l.product_id,
            COALESCE(p.denumire, l.unitate_masura),
            l.unitate_masura,
            l.stoc_scriptic,
            l.cantitate_numarata,
            l.cantitate_numarata - l.stoc_scriptic
        FROM public.physical_inventory_lines l
        LEFT JOIN public.products p ON p.id = l.product_id
        WHERE l.inventory_id = p_inventory_id
          AND l.cantitate_numarata IS NOT NULL
          AND l.cantitate_numarata <> l.stoc_scriptic;
    END IF;

    UPDATE public.physical_inventories
    SET status = 'finalized',
        finalized_at = v_posted_at,
        updated_at = v_posted_at
    WHERE id = p_inventory_id;
END;
$$;

ALTER TABLE public.warehouse_product_stocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_transfer_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_difference_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_difference_report_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS warehouse_product_stocks_select ON public.warehouse_product_stocks;
CREATE POLICY warehouse_product_stocks_select ON public.warehouse_product_stocks
    FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_inventory_data(company_id, 'view'::text, 'view'::text));

DROP POLICY IF EXISTS stock_transfers_select ON public.stock_transfers;
CREATE POLICY stock_transfers_select ON public.stock_transfers
    FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_inventory_data(company_id, 'view'::text, 'view'::text));

DROP POLICY IF EXISTS stock_transfer_lines_select ON public.stock_transfer_lines;
CREATE POLICY stock_transfer_lines_select ON public.stock_transfer_lines
    FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_inventory_data(company_id, 'view'::text, 'view'::text));

DROP POLICY IF EXISTS inventory_difference_reports_select ON public.inventory_difference_reports;
CREATE POLICY inventory_difference_reports_select ON public.inventory_difference_reports
    FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_inventory_data(company_id, 'view'::text, 'view'::text));

DROP POLICY IF EXISTS inventory_difference_report_lines_select ON public.inventory_difference_report_lines;
CREATE POLICY inventory_difference_report_lines_select ON public.inventory_difference_report_lines
    FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_inventory_data(company_id, 'view'::text, 'view'::text));

GRANT SELECT ON TABLE public.warehouse_product_stocks TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stock_transfers TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stock_transfer_lines TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.inventory_difference_reports TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.inventory_difference_report_lines TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.post_stock_transfer(UUID, DATE, UUID, UUID, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_stock_transfer(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.warehouse_stock_quantity(UUID, UUID, UUID) TO authenticated;
