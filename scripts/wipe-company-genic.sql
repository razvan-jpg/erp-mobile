-- Golește toate datele operaționale pentru societatea GENIC TEAM INTERNATIONAL SRL.
-- Păstrează înregistrarea societății, administratorul și drepturile acestuia.

BEGIN;

DO $$
DECLARE
    v_company_id UUID := '7fe42fd8-a72c-4135-9fba-586ca122ad56';
    v_company_name TEXT;
BEGIN
    SELECT denumire
    INTO v_company_name
    FROM public.companies
    WHERE id = v_company_id;

    IF v_company_name IS NULL THEN
        RAISE EXCEPTION 'Societatea GENIC nu a fost găsită.';
    END IF;

    RAISE NOTICE 'Golire date pentru societatea: %', v_company_name;

    DELETE FROM public.supplier_nir_lines WHERE company_id = v_company_id;
    DELETE FROM public.supplier_nirs WHERE company_id = v_company_id;
    DELETE FROM public.stock_movements WHERE company_id = v_company_id;
    DELETE FROM public.physical_inventory_lines WHERE company_id = v_company_id;
    DELETE FROM public.physical_inventories WHERE company_id = v_company_id;
    DELETE FROM public.supplier_payments WHERE company_id = v_company_id;
    DELETE FROM public.supplier_invoice_lines WHERE company_id = v_company_id;
    DELETE FROM public.supplier_invoices WHERE company_id = v_company_id;
    DELETE FROM public.product_stocks WHERE company_id = v_company_id;
    DELETE FROM public.products WHERE company_id = v_company_id;
    DELETE FROM public.suppliers WHERE company_id = v_company_id;
    DELETE FROM public.client_payments WHERE company_id = v_company_id;
    DELETE FROM public.client_invoices WHERE company_id = v_company_id;
    DELETE FROM public.clients WHERE company_id = v_company_id;
    DELETE FROM public.company_warehouses WHERE company_id = v_company_id;
    DELETE FROM public.company_work_locations WHERE company_id = v_company_id;

    RAISE NOTICE 'Golire finalizată pentru societatea: %', v_company_name;
END $$;

COMMIT;
