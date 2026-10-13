-- Nectarie: *2.PROMO-SGR-CARLSB.0.33ST(1=12ST) → catalog BERE CARLSBERG 0.33 L
-- Mută stoc, înlocuiește pe NIR / gestiune / linii factură, șterge vechiul.
-- Dezactivează trigger-ele de stoc pe NIR/mișcări ca să nu dublăm / recreăm rânduri.

DO $$
DECLARE
    v_company_id UUID;
    v_dup_id UUID := 'fd1ab64b-2bdc-435a-adad-2b3984a9b746';
    v_master_id UUID := 'a6492bf4-3447-4fa1-900d-6c5ef6b75d5c';
    v_dup_name TEXT;
    v_master_name TEXT;
    v_stock_before NUMERIC;
    v_stock_after NUMERIC;
BEGIN
    SELECT id INTO v_company_id
    FROM public.companies
    WHERE denumire ILIKE '%nectarie%'
    ORDER BY created_at NULLS LAST
    LIMIT 1;

    IF v_company_id IS NULL THEN
        RAISE EXCEPTION 'Nectarie not found';
    END IF;

    SELECT denumire INTO v_dup_name
    FROM public.products
    WHERE id = v_dup_id AND company_id = v_company_id;

    SELECT denumire INTO v_master_name
    FROM public.products
    WHERE id = v_master_id AND company_id = v_company_id AND in_catalog = true;

    IF v_dup_name IS NULL THEN
        RAISE NOTICE 'Dup already gone — nothing to do';
        RETURN;
    END IF;

    IF v_master_name IS NULL THEN
        RAISE EXCEPTION 'Catalog master BERE CARLSBERG 0.33 L not found';
    END IF;

    IF v_dup_name IS DISTINCT FROM '*2.PROMO-SGR-CARLSB.0.33ST(1=12ST)' THEN
        RAISE EXCEPTION 'Unexpected dup name: %', v_dup_name;
    END IF;

    SELECT COALESCE(SUM(cantitate), 0) INTO v_stock_before
    FROM public.product_stocks
    WHERE company_id = v_company_id
      AND product_id IN (v_dup_id, v_master_id);

    ALTER TABLE public.stock_movements DISABLE TRIGGER stock_movements_sync_warehouse_stock;
    ALTER TABLE public.supplier_nir_lines DISABLE TRIGGER supplier_nir_lines_stock_update;

    BEGIN
        UPDATE public.product_stocks m
        SET cantitate = m.cantitate + d.cantitate, updated_at = now()
        FROM public.product_stocks d
        WHERE d.product_id = v_dup_id AND d.company_id = v_company_id
          AND m.product_id = v_master_id AND m.company_id = v_company_id;

        INSERT INTO public.product_stocks (company_id, product_id, cantitate)
        SELECT d.company_id, v_master_id, d.cantitate
        FROM public.product_stocks d
        WHERE d.product_id = v_dup_id AND d.company_id = v_company_id
          AND NOT EXISTS (
              SELECT 1 FROM public.product_stocks m
              WHERE m.company_id = d.company_id AND m.product_id = v_master_id
          );

        DELETE FROM public.product_stocks
        WHERE product_id = v_dup_id AND company_id = v_company_id;

        UPDATE public.warehouse_product_stocks w
        SET cantitate = w.cantitate + d.cantitate, updated_at = now()
        FROM public.warehouse_product_stocks d
        WHERE d.product_id = v_dup_id AND d.company_id = v_company_id
          AND w.product_id = v_master_id
          AND w.company_id = d.company_id
          AND w.warehouse_id = d.warehouse_id;

        INSERT INTO public.warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
        SELECT d.company_id, d.warehouse_id, v_master_id, d.cantitate
        FROM public.warehouse_product_stocks d
        WHERE d.product_id = v_dup_id AND d.company_id = v_company_id
          AND NOT EXISTS (
              SELECT 1 FROM public.warehouse_product_stocks w
              WHERE w.company_id = d.company_id
                AND w.warehouse_id = d.warehouse_id
                AND w.product_id = v_master_id
          );

        DELETE FROM public.warehouse_product_stocks
        WHERE product_id = v_dup_id AND company_id = v_company_id;

        UPDATE public.supplier_nir_lines snl
        SET product_id = v_master_id
        FROM public.supplier_nirs sn
        WHERE snl.nir_id = sn.id
          AND sn.company_id = v_company_id
          AND snl.product_id = v_dup_id;

        UPDATE public.supplier_invoice_lines
        SET product_id = v_master_id
        WHERE company_id = v_company_id AND product_id = v_dup_id;

        UPDATE public.stock_movements
        SET product_id = v_master_id
        WHERE company_id = v_company_id AND product_id = v_dup_id;

        UPDATE public.stock_transfer_lines
        SET product_id = v_master_id
        WHERE company_id = v_company_id AND product_id = v_dup_id;

        UPDATE public.physical_inventory_lines
        SET product_id = v_master_id
        WHERE company_id = v_company_id AND product_id = v_dup_id;

        UPDATE public.inventory_difference_report_lines
        SET product_id = v_master_id
        WHERE company_id = v_company_id AND product_id = v_dup_id;

        UPDATE public.product_recipe_lines SET product_id = v_master_id WHERE product_id = v_dup_id;
        UPDATE public.product_recipe_lines SET ingredient_product_id = v_master_id WHERE ingredient_product_id = v_dup_id;

        UPDATE public.company_fiscal_sale_receipt_lines
        SET product_id = v_master_id
        WHERE company_id = v_company_id AND product_id = v_dup_id;

        UPDATE public.crm_deal_products SET product_id = v_master_id WHERE product_id = v_dup_id;
        UPDATE public.crm_quote_lines SET product_id = v_master_id WHERE product_id = v_dup_id;

        DELETE FROM public.product_sale_addons
        WHERE company_id = v_company_id
          AND (
              (product_id = v_dup_id AND addon_product_id = v_master_id)
              OR (product_id = v_master_id AND addon_product_id = v_dup_id)
              OR (product_id = v_dup_id AND addon_product_id = v_dup_id)
          );

        UPDATE public.product_sale_addons
        SET product_id = v_master_id
        WHERE product_id = v_dup_id AND company_id = v_company_id
          AND NOT EXISTS (
              SELECT 1 FROM public.product_sale_addons x
              WHERE x.company_id = v_company_id
                AND x.product_id = v_master_id
                AND x.addon_product_id = product_sale_addons.addon_product_id
          );
        DELETE FROM public.product_sale_addons
        WHERE product_id = v_dup_id AND company_id = v_company_id;

        UPDATE public.product_sale_addons
        SET addon_product_id = v_master_id
        WHERE addon_product_id = v_dup_id AND company_id = v_company_id
          AND NOT EXISTS (
              SELECT 1 FROM public.product_sale_addons x
              WHERE x.company_id = v_company_id
                AND x.product_id = product_sale_addons.product_id
                AND x.addon_product_id = v_master_id
          );
        DELETE FROM public.product_sale_addons
        WHERE addon_product_id = v_dup_id AND company_id = v_company_id;

        DELETE FROM public.cm_product_group_members
        WHERE product_id = v_dup_id AND company_id = v_company_id;

        -- Safety: clear any stock rows recreated mid-flight
        DELETE FROM public.product_stocks
        WHERE product_id = v_dup_id AND company_id = v_company_id;
        DELETE FROM public.warehouse_product_stocks
        WHERE product_id = v_dup_id AND company_id = v_company_id;

        DELETE FROM public.products
        WHERE id = v_dup_id AND company_id = v_company_id;

    EXCEPTION WHEN OTHERS THEN
        ALTER TABLE public.supplier_nir_lines ENABLE TRIGGER supplier_nir_lines_stock_update;
        ALTER TABLE public.stock_movements ENABLE TRIGGER stock_movements_sync_warehouse_stock;
        RAISE;
    END;

    ALTER TABLE public.supplier_nir_lines ENABLE TRIGGER supplier_nir_lines_stock_update;
    ALTER TABLE public.stock_movements ENABLE TRIGGER stock_movements_sync_warehouse_stock;

    SELECT COALESCE(SUM(cantitate), 0) INTO v_stock_after
    FROM public.product_stocks
    WHERE company_id = v_company_id
      AND product_id = v_master_id;

    IF v_stock_before IS DISTINCT FROM v_stock_after THEN
        RAISE EXCEPTION 'Stock mismatch: before(dup+master)=% after(master)=%', v_stock_before, v_stock_after;
    END IF;

    IF EXISTS (SELECT 1 FROM public.products WHERE id = v_dup_id) THEN
        RAISE EXCEPTION 'Dup product still exists';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.supplier_nir_lines snl
        JOIN public.supplier_nirs sn ON sn.id = snl.nir_id
        WHERE sn.company_id = v_company_id AND snl.product_id = v_dup_id
    ) THEN
        RAISE EXCEPTION 'NIR lines still point to dup';
    END IF;

    RAISE NOTICE 'Merged "%" → "%" ; master stock=%', v_dup_name, v_master_name, v_stock_after;
END $$;
