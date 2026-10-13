-- Unificare făină: cod 1234 („faina”, inactiv) → master 228368 („FAINA”).
-- Nu modificăm in_catalog pe master.
DO $$
DECLARE
  master_id uuid := '7a04a867-f627-4f34-b85a-53534d343d02'; -- 228368 FAINA
  dup_id uuid := '163c0bed-c89b-4994-ac6a-5e8d70446f7e';    -- 1234 faina
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.products WHERE id = master_id) THEN
    RAISE EXCEPTION 'Master FAINA 228368 missing';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.products WHERE id = dup_id) THEN
    RAISE NOTICE 'Dup 1234 already gone';
    RETURN;
  END IF;

  UPDATE public.products
  SET denumire = 'FAINA', is_active = true, updated_at = now()
  WHERE id = master_id;

  -- Rețete: evită conflict UNIQUE
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

  -- Grupe CM
  DELETE FROM public.cm_product_group_members d
  WHERE d.product_id = dup_id
    AND EXISTS (
      SELECT 1 FROM public.cm_product_group_members m
      WHERE m.group_id = d.group_id AND m.product_id = master_id
    );
  UPDATE public.cm_product_group_members SET product_id = master_id WHERE product_id = dup_id;

  -- Meniuri CM
  UPDATE public.cm_menu_lines SET product_id = master_id WHERE product_id = dup_id;

  -- Sale addons
  DELETE FROM public.product_sale_addons d
  WHERE d.addon_product_id = dup_id
    AND EXISTS (
      SELECT 1 FROM public.product_sale_addons m
      WHERE m.product_id = d.product_id AND m.addon_product_id = master_id
    );
  UPDATE public.product_sale_addons SET product_id = master_id WHERE product_id = dup_id;
  UPDATE public.product_sale_addons SET addon_product_id = master_id WHERE addon_product_id = dup_id;

  UPDATE public.supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
  UPDATE public.supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
  UPDATE public.stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
  UPDATE public.stock_movements SET product_id = master_id WHERE product_id = dup_id;
  UPDATE public.physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
  UPDATE public.inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
  UPDATE public.crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
  UPDATE public.crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
  UPDATE public.company_fiscal_sale_receipt_lines SET product_id = master_id WHERE product_id = dup_id;
  UPDATE public.product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
  UPDATE public.product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;

  -- Stoc pe gestiune
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

  -- Stoc agregat
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

  DELETE FROM public.products WHERE id = dup_id;
END $$;
