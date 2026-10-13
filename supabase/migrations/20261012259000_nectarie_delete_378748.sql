-- NECTARIE: sterge codul 378748.

DO $$
DECLARE
  v_company uuid := '10690ba8-f7cf-47a4-8f93-712d69f5e5a2';
  v_id uuid;
BEGIN
  SELECT id INTO v_id
  FROM public.products
  WHERE company_id = v_company AND cod = '378748'
  LIMIT 1;

  IF v_id IS NULL THEN
    RAISE NOTICE 'cod 378748 already absent';
    RETURN;
  END IF;

  DELETE FROM public.product_recipe_lines
  WHERE company_id = v_company
    AND (ingredient_product_id = v_id OR product_id = v_id);

  DELETE FROM public.cm_product_group_members WHERE product_id = v_id;
  DELETE FROM public.cm_menu_lines WHERE product_id = v_id;
  DELETE FROM public.product_sale_addons
  WHERE company_id = v_company
    AND (product_id = v_id OR addon_product_id = v_id);

  DELETE FROM public.warehouse_product_stocks WHERE product_id = v_id AND company_id = v_company;
  DELETE FROM public.product_stocks WHERE product_id = v_id AND company_id = v_company;

  DELETE FROM public.stock_movements WHERE product_id = v_id AND company_id = v_company;
  DELETE FROM public.stock_transfer_lines WHERE product_id = v_id;
  DELETE FROM public.supplier_invoice_lines WHERE product_id = v_id;
  DELETE FROM public.supplier_nir_lines WHERE product_id = v_id;
  DELETE FROM public.physical_inventory_lines WHERE product_id = v_id;
  DELETE FROM public.inventory_difference_report_lines WHERE product_id = v_id;
  DELETE FROM public.company_fiscal_sale_receipt_lines WHERE product_id = v_id;
  DELETE FROM public.production_voucher_lines WHERE product_id = v_id;
  DELETE FROM public.production_vouchers WHERE product_id = v_id;
  DELETE FROM public.crm_deal_products WHERE product_id = v_id;
  DELETE FROM public.crm_quote_lines WHERE product_id = v_id;

  DELETE FROM public.products WHERE id = v_id AND company_id = v_company;
END $$;
