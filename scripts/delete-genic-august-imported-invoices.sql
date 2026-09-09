-- Șterge facturile GENIC cu data_factura în august 2026 (inclusiv NIR-uri și stornare stoc).
-- Nu atinge facturile din alte luni.

BEGIN;

DO $$
DECLARE
    v_company_id UUID := '7fe42fd8-a72c-4135-9fba-586ca122ad56';
    v_company_name TEXT;
    v_invoices INT;
    v_nirs INT;
    v_lines INT;
    v_nir RECORD;
BEGIN
    SELECT denumire INTO v_company_name
    FROM public.companies
    WHERE id = v_company_id;

    IF v_company_name IS NULL OR v_company_name NOT ILIKE '%genic%' THEN
        RAISE EXCEPTION 'Societatea GENIC nu a fost găsită.';
    END IF;

    CREATE TEMP TABLE tmp_genic_august_invoices ON COMMIT DROP AS
    SELECT id
    FROM public.supplier_invoices
    WHERE company_id = v_company_id
      AND data_factura >= DATE '2026-08-01'
      AND data_factura < DATE '2026-09-01';

    SELECT count(*) INTO v_invoices FROM tmp_genic_august_invoices;
    SELECT count(*) INTO v_nirs
    FROM public.supplier_nirs n
    JOIN tmp_genic_august_invoices i ON i.id = n.invoice_id;
    SELECT count(*) INTO v_lines
    FROM public.supplier_invoice_lines l
    JOIN tmp_genic_august_invoices i ON i.id = l.invoice_id;

    RAISE NOTICE 'GENIC %: șterg % facturi august, % NIR, % linii',
        v_company_name, v_invoices, v_nirs, v_lines;

    FOR v_nir IN
        SELECT n.company_id, n.invoice_id, n.numar_nir
        FROM public.supplier_nirs n
        JOIN tmp_genic_august_invoices i ON i.id = n.invoice_id
    LOOP
        PERFORM public.release_supplier_nir_number(
            v_nir.company_id,
            v_nir.invoice_id,
            v_nir.numar_nir,
            true
        );
    END LOOP;

    DELETE FROM public.supplier_nirs n
    USING tmp_genic_august_invoices i
    WHERE n.invoice_id = i.id;

    DELETE FROM public.supplier_invoice_lines l
    USING tmp_genic_august_invoices i
    WHERE l.invoice_id = i.id;

    DELETE FROM public.supplier_invoices si
    USING tmp_genic_august_invoices i
    WHERE si.id = i.id;

    RAISE NOTICE 'Ștergere finalizată.';
END $$;

COMMIT;

SELECT
    (SELECT count(*) FROM public.supplier_invoices
      WHERE company_id = '7fe42fd8-a72c-4135-9fba-586ca122ad56'
        AND data_factura >= DATE '2026-08-01'
        AND data_factura < DATE '2026-09-01') AS facturi_august_ramase,
    (SELECT count(*) FROM public.supplier_nirs n
      JOIN public.supplier_invoices si ON si.id = n.invoice_id
      WHERE si.company_id = '7fe42fd8-a72c-4135-9fba-586ca122ad56'
        AND si.data_factura >= DATE '2026-08-01'
        AND si.data_factura < DATE '2026-09-01') AS nir_august_ramase,
    (SELECT count(*) FROM public.supplier_invoices
      WHERE company_id = '7fe42fd8-a72c-4135-9fba-586ca122ad56') AS facturi_genic_total;
