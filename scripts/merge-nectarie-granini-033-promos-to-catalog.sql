-- Nectarie: *2.SGR-Granini 0.33l… + Tbg/TBG Granini 0.33 → catalog GRANINI 0.33 L

DO $$
DECLARE
    v_company_id UUID;
    v_master_id UUID := 'aa8255e8-0bce-422c-8e5e-a80d99b64664';
    v_master_name TEXT;
    v_dup RECORD;
    v_stock_before NUMERIC;
    v_stock_after NUMERIC;
    v_dup_ids UUID[] := ARRAY[
        '670cf5a5-5173-4f7d-8cf6-fe597b9b1958'::uuid, -- *2.SGR-Granini 0.33l Limon.-Menta(12buc)
        'b3d3a169-5954-4057-b570-f3c43a4ace68'::uuid, -- *2.SGR-Granini 0.33l Piersica (1=12buc)pet
        '506226e1-032a-44e3-988f-a158b66a8f55'::uuid, -- *2.SGR-Granini 0.33l Visine (1=12buc)pet
        'efe92c94-14b3-48e1-ad07-d231fdf9bd72'::uuid, -- TBG-GRANINI Limonada + capsuni 0.33L …
        'a7e9cad0-b2e5-438b-bd72-c43f1a6c9d77'::uuid, -- Tbg-Granini piersici 0.33l …
        'b592acb8-4b00-46ae-b5ce-13c9daff9f8c'::uuid, -- Tbg-Granini piersici 0.33l … promo
        'e5784c73-a61b-4d61-9628-7eaeb00b6266'::uuid, -- Tbg-Granini portocale 0.33 …
        'a30f52bc-1572-4dba-9d20-0d45b258b2b1'::uuid, -- Tbg-Granini portocale 0.33 … promo
        'c69254ed-e095-431d-8c54-e4791ed90fc8'::uuid, -- Tbg-Granini visine 0.33 …
        'e34de795-9972-4790-a7d0-4f610a524ea6'::uuid  -- Tbg-Granini visine 0.33 … promo
    ];
    v_merged INT := 0;
BEGIN
    SELECT id INTO v_company_id
    FROM public.companies
    WHERE denumire ILIKE '%nectarie%'
    ORDER BY created_at NULLS LAST
    LIMIT 1;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'Nectarie not found';
    END IF;

    SELECT denumire INTO v_master_name
    FROM public.products
    WHERE id = v_master_id AND company_id = v_company_id AND in_catalog = true;

    IF v_master_name IS NULL OR v_master_name IS DISTINCT FROM 'GRANINI 0.33 L' THEN
        RAISE EXCEPTION 'Catalog master GRANINI 0.33 L not found (got %)', v_master_name;
    END IF;

    SELECT COALESCE(SUM(cantitate), 0) INTO v_stock_before
    FROM public.product_stocks
    WHERE company_id = v_company_id
      AND product_id = ANY (v_dup_ids || v_master_id);

    ALTER TABLE public.stock_movements DISABLE TRIGGER stock_movements_sync_warehouse_stock;
    ALTER TABLE public.supplier_nir_lines DISABLE TRIGGER supplier_nir_lines_stock_update;

    BEGIN
        FOR v_dup IN
            SELECT id, denumire FROM public.products
            WHERE company_id = v_company_id
              AND id = ANY (v_dup_ids)
        LOOP
            IF lower(v_dup.denumire) NOT LIKE '%granini%' THEN
                RAISE EXCEPTION 'Unexpected non-Granini dup: %', v_dup.denumire;
            END IF;
            IF v_dup.denumire !~* '0[.,]?33' THEN
                RAISE EXCEPTION 'Unexpected non-0.33 Granini dup: %', v_dup.denumire;
            END IF;

            UPDATE public.product_stocks m
            SET cantitate = m.cantitate + d.cantitate, updated_at = now()
            FROM public.product_stocks d
            WHERE d.product_id = v_dup.id AND d.company_id = v_company_id
              AND m.product_id = v_master_id AND m.company_id = v_company_id;

            INSERT INTO public.product_stocks (company_id, product_id, cantitate)
            SELECT d.company_id, v_master_id, d.cantitate
            FROM public.product_stocks d
            WHERE d.product_id = v_dup.id AND d.company_id = v_company_id
              AND NOT EXISTS (
                  SELECT 1 FROM public.product_stocks m
                  WHERE m.company_id = d.company_id AND m.product_id = v_master_id
              );

            DELETE FROM public.product_stocks
            WHERE product_id = v_dup.id AND company_id = v_company_id;

            UPDATE public.warehouse_product_stocks w
            SET cantitate = w.cantitate + d.cantitate, updated_at = now()
            FROM public.warehouse_product_stocks d
            WHERE d.product_id = v_dup.id AND d.company_id = v_company_id
              AND w.product_id = v_master_id
              AND w.company_id = d.company_id
              AND w.warehouse_id = d.warehouse_id;

            INSERT INTO public.warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
            SELECT d.company_id, d.warehouse_id, v_master_id, d.cantitate
            FROM public.warehouse_product_stocks d
            WHERE d.product_id = v_dup.id AND d.company_id = v_company_id
              AND NOT EXISTS (
                  SELECT 1 FROM public.warehouse_product_stocks w
                  WHERE w.company_id = d.company_id
                    AND w.warehouse_id = d.warehouse_id
                    AND w.product_id = v_master_id
              );

            DELETE FROM public.warehouse_product_stocks
            WHERE product_id = v_dup.id AND company_id = v_company_id;

            UPDATE public.supplier_nir_lines snl
            SET product_id = v_master_id
            FROM public.supplier_nirs sn
            WHERE snl.nir_id = sn.id
              AND sn.company_id = v_company_id
              AND snl.product_id = v_dup.id;

            UPDATE public.supplier_invoice_lines
            SET product_id = v_master_id
            WHERE company_id = v_company_id AND product_id = v_dup.id;

            UPDATE public.stock_movements
            SET product_id = v_master_id
            WHERE company_id = v_company_id AND product_id = v_dup.id;

            UPDATE public.stock_transfer_lines
            SET product_id = v_master_id
            WHERE company_id = v_company_id AND product_id = v_dup.id;

            UPDATE public.physical_inventory_lines
            SET product_id = v_master_id
            WHERE company_id = v_company_id AND product_id = v_dup.id;

            UPDATE public.inventory_difference_report_lines
            SET product_id = v_master_id
            WHERE company_id = v_company_id AND product_id = v_dup.id;

            UPDATE public.product_recipe_lines SET product_id = v_master_id WHERE product_id = v_dup.id;
            UPDATE public.product_recipe_lines SET ingredient_product_id = v_master_id WHERE ingredient_product_id = v_dup.id;

            UPDATE public.company_fiscal_sale_receipt_lines
            SET product_id = v_master_id
            WHERE company_id = v_company_id AND product_id = v_dup.id;

            UPDATE public.crm_deal_products SET product_id = v_master_id WHERE product_id = v_dup.id;
            UPDATE public.crm_quote_lines SET product_id = v_master_id WHERE product_id = v_dup.id;

            DELETE FROM public.product_sale_addons
            WHERE company_id = v_company_id
              AND (
                  (product_id = v_dup.id AND addon_product_id = v_master_id)
                  OR (product_id = v_master_id AND addon_product_id = v_dup.id)
                  OR (product_id = v_dup.id AND addon_product_id = v_dup.id)
              );

            UPDATE public.product_sale_addons
            SET product_id = v_master_id
            WHERE product_id = v_dup.id AND company_id = v_company_id
              AND NOT EXISTS (
                  SELECT 1 FROM public.product_sale_addons x
                  WHERE x.company_id = v_company_id
                    AND x.product_id = v_master_id
                    AND x.addon_product_id = product_sale_addons.addon_product_id
              );
            DELETE FROM public.product_sale_addons
            WHERE product_id = v_dup.id AND company_id = v_company_id;

            UPDATE public.product_sale_addons
            SET addon_product_id = v_master_id
            WHERE addon_product_id = v_dup.id AND company_id = v_company_id
              AND NOT EXISTS (
                  SELECT 1 FROM public.product_sale_addons x
                  WHERE x.company_id = v_company_id
                    AND x.product_id = product_sale_addons.product_id
                    AND x.addon_product_id = v_master_id
              );
            DELETE FROM public.product_sale_addons
            WHERE addon_product_id = v_dup.id AND company_id = v_company_id;

            DELETE FROM public.cm_product_group_members
            WHERE product_id = v_dup.id AND company_id = v_company_id;

            DELETE FROM public.product_stocks
            WHERE product_id = v_dup.id AND company_id = v_company_id;
            DELETE FROM public.warehouse_product_stocks
            WHERE product_id = v_dup.id AND company_id = v_company_id;

            DELETE FROM public.products
            WHERE id = v_dup.id AND company_id = v_company_id;

            v_merged := v_merged + 1;
            RAISE NOTICE 'Merged "%" → "%"', v_dup.denumire, v_master_name;
        END LOOP;

    EXCEPTION WHEN OTHERS THEN
        ALTER TABLE public.supplier_nir_lines ENABLE TRIGGER supplier_nir_lines_stock_update;
        ALTER TABLE public.stock_movements ENABLE TRIGGER stock_movements_sync_warehouse_stock;
        RAISE;
    END;

    ALTER TABLE public.supplier_nir_lines ENABLE TRIGGER supplier_nir_lines_stock_update;
    ALTER TABLE public.stock_movements ENABLE TRIGGER stock_movements_sync_warehouse_stock;

    IF v_merged = 0 THEN
        RAISE NOTICE 'No dups left — nothing to do';
        RETURN;
    END IF;

    SELECT COALESCE(SUM(cantitate), 0) INTO v_stock_after
    FROM public.product_stocks
    WHERE company_id = v_company_id
      AND product_id = v_master_id;

    IF v_stock_before IS DISTINCT FROM v_stock_after THEN
        RAISE EXCEPTION 'Stock mismatch: before(dup+master)=% after(master)=%', v_stock_before, v_stock_after;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.products
        WHERE company_id = v_company_id AND id = ANY (v_dup_ids)
    ) THEN
        RAISE EXCEPTION 'Dup product still exists';
    END IF;

    RAISE NOTICE 'Done; merged % → "%" stock=%', v_merged, v_master_name, v_stock_after;
END $$;
