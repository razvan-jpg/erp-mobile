-- Unificare produse pe lot → o fișă fără LOT (Nectarie)
DO $$
DECLARE
  master_id uuid;
  dup_id uuid;
BEGIN
  master_id := 'b1485b63-748b-45b7-bb08-f93f1caa05ed';
  UPDATE products SET denumire = 'DONER VITA TOCAT' WHERE id = master_id;
  dup_id := '120923d9-552d-4e45-95b3-3e41da174774';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := 'b9839ecc-a3fd-402a-aa46-aba6ea35acaf';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '8acf7488-b33e-4688-81dd-4c1c8060aeb7';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := 'b5cb2179-9ac6-4e1b-bbf6-3488209f8358';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '7863e640-e3a7-4796-b5ab-88aa1050424e';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '839c4c69-4d5b-4035-bd6f-a67bba47b3fa';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '25a0f710-b5cf-4c46-bb6d-5798294b378e';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '5b64369d-51e9-47fb-b739-0038aa8e1825';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '0d2b1fe6-e4c1-4eda-b561-59ee7362c6fa';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '0253e010-8510-4ca8-bcf3-36297dbd8790';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '737a0ce8-d462-4ed2-a05e-9357e649e9ff';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '7a6ed7ea-8e08-48cc-926f-b358e30a050c';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := 'c0ba9ba4-0e4a-4d43-9593-9a582b5b5268';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := 'd1a90fce-ad96-44d4-af34-03002a5ef700';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '8e66bea1-8359-47c4-8687-34ec83d7ecf5';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := 'd8ed3d04-155f-44b5-bba9-f42669010624';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '7a1ae652-e046-4a8c-8bdc-4b060dfe3183';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '892120f3-acb4-4fb5-98e1-b61cb7493893';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '62b2c1e2-2ce5-4932-8f3b-d0956e1cf23f';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := '02c82d45-8cf0-437c-8179-17f5a88077ec';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  master_id := 'a5c61a99-37fe-4c2c-a9ea-db7cc4e8813c';
  UPDATE products SET denumire = 'ALFA ULEI DE PALMIER (OLEINA) CUTIE 18 L' WHERE id = master_id;
  dup_id := '82de011d-84b6-4316-9715-3b31e3e3b02d';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := 'eaa82fd8-140b-481a-b4fd-85a874e437c3';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

  dup_id := 'e0c09f6f-7ca5-490e-957a-ba19603cb0ba';

    UPDATE supplier_nir_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE supplier_invoice_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_transfer_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE stock_movements SET product_id = master_id WHERE product_id = dup_id;
    UPDATE physical_inventory_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE inventory_difference_report_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_deal_products SET product_id = master_id WHERE product_id = dup_id;
    UPDATE crm_quote_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET product_id = master_id WHERE product_id = dup_id;
    UPDATE product_recipe_lines SET ingredient_product_id = master_id WHERE ingredient_product_id = dup_id;
    UPDATE warehouse_product_stocks w SET cantitate = w.cantitate + d.cantitate
      FROM warehouse_product_stocks d
      WHERE d.product_id = dup_id AND w.product_id = master_id
        AND w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id;
    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM warehouse_product_stocks w WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;
    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate FROM product_stocks d
      WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;

END $$;

SELECT p.denumire, ROUND(COALESCE(ps.cantitate,0)::numeric,2) AS stoc
FROM products p
LEFT JOIN product_stocks ps ON ps.product_id=p.id
WHERE p.id IN ('b1485b63-748b-45b7-bb08-f93f1caa05ed','a5c61a99-37fe-4c2c-a9ea-db7cc4e8813c');
