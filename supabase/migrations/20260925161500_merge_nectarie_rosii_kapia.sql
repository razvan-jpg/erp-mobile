-- Unificare roșii + ardei kapia (Nectarie)
DO $$
DECLARE
  master_id uuid;
  dup_id uuid;
  dups uuid[];
  i int;
BEGIN
  -- ROSII RO master
  master_id := '5253d27c-cef1-41d0-9fd6-5e1bde9c8149';
  UPDATE products SET denumire = 'ROSII RO' WHERE id = master_id;
  dups := ARRAY[
    'e6d37ed2-965c-4205-bcca-b9f84e931ae2'::uuid, -- ROSII P
    'a7fa13cf-80b1-402a-808a-b4ebcf56756b'::uuid, -- MC ROSII CIORCHINE
    'a277a2fb-2c4c-48dd-b65a-2bee854f9773'::uuid  -- Rosii
  ];
  FOREACH dup_id IN ARRAY dups LOOP
    -- rețete: evită conflict UNIQUE (product_id, ingredient_product_id)
    DELETE FROM product_recipe_lines d
    WHERE d.ingredient_product_id = dup_id
      AND EXISTS (
        SELECT 1 FROM product_recipe_lines m
        WHERE m.product_id = d.product_id AND m.ingredient_product_id = master_id
      );
    DELETE FROM product_recipe_lines d
    WHERE d.product_id = dup_id
      AND EXISTS (
        SELECT 1 FROM product_recipe_lines m
        WHERE m.product_id = master_id AND m.ingredient_product_id = d.ingredient_product_id
      );

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
      SELECT 1 FROM warehouse_product_stocks w
      WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;

    UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate
    FROM product_stocks d WHERE m.product_id = master_id AND d.product_id = dup_id;
    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
    WHERE d.product_id = dup_id AND NOT EXISTS (
      SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;
  END LOOP;

  -- ARDEI KAPIA ROSU master
  master_id := 'bb6da7ec-cb2d-4b24-ad0b-8c0b44cd71ac';
  UPDATE products SET denumire = 'ARDEI KAPIA ROSU' WHERE id = master_id;
  dup_id := 'e888f7bd-5e10-46a1-ba55-e5c5587a8390'; -- ardei kapia

  DELETE FROM product_recipe_lines d
  WHERE d.ingredient_product_id = dup_id
    AND EXISTS (
      SELECT 1 FROM product_recipe_lines m
      WHERE m.product_id = d.product_id AND m.ingredient_product_id = master_id
    );
  DELETE FROM product_recipe_lines d
  WHERE d.product_id = dup_id
    AND EXISTS (
      SELECT 1 FROM product_recipe_lines m
      WHERE m.product_id = master_id AND m.ingredient_product_id = d.ingredient_product_id
    );

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
    SELECT 1 FROM warehouse_product_stocks w
    WHERE w.company_id=d.company_id AND w.warehouse_id=d.warehouse_id AND w.product_id=master_id);
  DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;

  UPDATE product_stocks m SET cantitate = m.cantitate + d.cantitate
  FROM product_stocks d WHERE m.product_id = master_id AND d.product_id = dup_id;
  INSERT INTO product_stocks (company_id, product_id, cantitate)
  SELECT d.company_id, master_id, d.cantitate FROM product_stocks d
  WHERE d.product_id = dup_id AND NOT EXISTS (
    SELECT 1 FROM product_stocks m WHERE m.product_id=master_id AND m.company_id=d.company_id);
  DELETE FROM product_stocks WHERE product_id = dup_id;
  DELETE FROM products WHERE id = dup_id;
END $$;

SELECT p.denumire, ROUND(COALESCE(ps.cantitate,0)::numeric,2) AS stoc
FROM products p
LEFT JOIN product_stocks ps ON ps.product_id = p.id
WHERE p.id IN (
  '5253d27c-cef1-41d0-9fd6-5e1bde9c8149',
  'bb6da7ec-cb2d-4b24-ad0b-8c0b44cd71ac'
);
