-- NECTARIE: master LAY'S SARE (cod 340059584); unifica varianta DTS.
-- Nu modificam in_catalog.

DO $$
DECLARE
  v_company uuid := '10690ba8-f7cf-47a4-8f93-712d69f5e5a2';
  master_id uuid := '46002709-a5e9-422d-a36f-2202b8f321f3'; -- 340059584
  dup_id uuid := 'd1188200-4087-4147-9ce2-57963e7bcd8f';    -- 340062681 DTS
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.products
    WHERE id = master_id AND company_id = v_company AND cod = '340059584'
  ) THEN
    RAISE EXCEPTION 'Master LAY''S SARE 340059584 missing';
  END IF;

  UPDATE public.products
  SET denumire = 'LAY''S SARE',
      is_active = true,
      updated_at = now()
  WHERE id = master_id AND company_id = v_company;

  IF NOT EXISTS (
    SELECT 1 FROM public.products WHERE id = dup_id AND company_id = v_company
  ) THEN
    RAISE NOTICE 'DTS dup already gone';
    RETURN;
  END IF;

  ALTER TABLE public.stock_movements DISABLE TRIGGER stock_movements_sync_warehouse_stock;
  ALTER TABLE public.supplier_nir_lines DISABLE TRIGGER supplier_nir_lines_stock_in;
  ALTER TABLE public.supplier_nir_lines DISABLE TRIGGER supplier_nir_lines_stock_out;
  ALTER TABLE public.supplier_nir_lines DISABLE TRIGGER supplier_nir_lines_stock_update;

  BEGIN
    DELETE FROM public.product_recipe_lines d
    WHERE d.ingredient_product_id = dup_id
      AND EXISTS (
        SELECT 1 FROM public.product_recipe_lines m
        WHERE m.product_id = d.product_id AND m.ingredient_product_id = master_id
      );
    DELETE FROM public.product_recipe_lines d
    WHERE d.product_id = dup_id
      AND EXISTS (
        SELECT 1 FROM public.product_recipe_lines m
        WHERE m.product_id = master_id AND m.ingredient_product_id = d.ingredient_product_id
      );
    UPDATE public.product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;

    DELETE FROM public.cm_product_group_members d
    WHERE d.product_id = dup_id
      AND EXISTS (
        SELECT 1 FROM public.cm_product_group_members m
        WHERE m.group_id = d.group_id AND m.product_id = master_id
      );
    UPDATE public.cm_product_group_members SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.cm_menu_lines SET product_id = master_id WHERE product_id = dup_id;

    DELETE FROM public.product_sale_addons d
    WHERE d.company_id = v_company
      AND (
        (d.product_id = dup_id AND d.addon_product_id = master_id)
        OR (d.product_id = master_id AND d.addon_product_id = dup_id)
        OR (d.product_id = dup_id AND d.addon_product_id = dup_id)
      );
    UPDATE public.product_sale_addons SET product_id = master_id
    WHERE product_id = dup_id AND company_id = v_company;
    UPDATE public.product_sale_addons SET addon_product_id = master_id
    WHERE addon_product_id = dup_id AND company_id = v_company;

    UPDATE public.supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.company_fiscal_sale_receipt_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.production_voucher_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE public.production_vouchers SET product_id = master_id WHERE product_id = dup_id;

    UPDATE public.warehouse_product_stocks w
    SET cantitate = w.cantitate + d.cantitate, updated_at = now()
    FROM public.warehouse_product_stocks d
    WHERE d.product_id = dup_id
      AND w.product_id = master_id
      AND w.company_id = d.company_id
      AND w.warehouse_id = d.warehouse_id;
    INSERT INTO public.warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate
    FROM public.warehouse_product_stocks d
    WHERE d.product_id = dup_id
      AND NOT EXISTS (
        SELECT 1 FROM public.warehouse_product_stocks w
        WHERE w.company_id = d.company_id
          AND w.warehouse_id = d.warehouse_id
          AND w.product_id = master_id
      );
    DELETE FROM public.warehouse_product_stocks WHERE product_id = dup_id;

    UPDATE public.product_stocks m
    SET cantitate = m.cantitate + d.cantitate, updated_at = now()
    FROM public.product_stocks d
    WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO public.product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate
    FROM public.product_stocks d
    WHERE d.product_id = dup_id
      AND NOT EXISTS (
        SELECT 1 FROM public.product_stocks m
        WHERE m.product_id = master_id AND m.company_id = d.company_id
      );
    DELETE FROM public.product_stocks WHERE product_id = dup_id;

    DELETE FROM public.products WHERE id = dup_id AND company_id = v_company;
  EXCEPTION WHEN OTHERS THEN
    ALTER TABLE public.stock_movements ENABLE TRIGGER stock_movements_sync_warehouse_stock;
    ALTER TABLE public.supplier_nir_lines ENABLE TRIGGER supplier_nir_lines_stock_in;
    ALTER TABLE public.supplier_nir_lines ENABLE TRIGGER supplier_nir_lines_stock_out;
    ALTER TABLE public.supplier_nir_lines ENABLE TRIGGER supplier_nir_lines_stock_update;
    RAISE;
  END;

  ALTER TABLE public.stock_movements ENABLE TRIGGER stock_movements_sync_warehouse_stock;
  ALTER TABLE public.supplier_nir_lines ENABLE TRIGGER supplier_nir_lines_stock_in;
  ALTER TABLE public.supplier_nir_lines ENABLE TRIGGER supplier_nir_lines_stock_out;
  ALTER TABLE public.supplier_nir_lines ENABLE TRIGGER supplier_nir_lines_stock_update;
END $$;
