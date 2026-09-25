-- Unificare variante cartofi albi/noi → CARTOFI ALBI IMP (Nectarie)
DO $$
DECLARE
  master_id uuid := '4a84f6bb-020e-4793-8b78-4b345602a7e6';
  dup_id uuid;
  dups uuid[] := ARRAY[
    'cc0d0f89-6f85-4290-8f4d-c73974e9c60a'::uuid, -- CARTOFI ALBI RO 50+
    '81476ce1-15ec-40fe-9c08-e0eb1aaa6bfb'::uuid, -- CARTOFI NOI RO
    'b869d047-cdee-471b-9baf-b257195636f8'::uuid  -- MC CARTOFI ALBI 10KG
  ];
BEGIN
  FOREACH dup_id IN ARRAY dups LOOP
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

    UPDATE warehouse_product_stocks w
    SET cantitate = w.cantitate + d.cantitate
    FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id
      AND w.product_id = master_id
      AND w.company_id = d.company_id
      AND w.warehouse_id = d.warehouse_id;

    INSERT INTO warehouse_product_stocks (company_id, warehouse_id, product_id, cantitate)
    SELECT d.company_id, d.warehouse_id, master_id, d.cantitate
    FROM warehouse_product_stocks d
    WHERE d.product_id = dup_id
      AND NOT EXISTS (
        SELECT 1 FROM warehouse_product_stocks w
        WHERE w.company_id = d.company_id AND w.warehouse_id = d.warehouse_id AND w.product_id = master_id
      );

    DELETE FROM warehouse_product_stocks WHERE product_id = dup_id;

    UPDATE product_stocks m
    SET cantitate = m.cantitate + d.cantitate
    FROM product_stocks d
    WHERE m.product_id = master_id AND d.product_id = dup_id;

    INSERT INTO product_stocks (company_id, product_id, cantitate)
    SELECT d.company_id, master_id, d.cantitate
    FROM product_stocks d
    WHERE d.product_id = dup_id
      AND NOT EXISTS (SELECT 1 FROM product_stocks m WHERE m.product_id = master_id AND m.company_id = d.company_id);

    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;
  END LOOP;
END $$;

SELECT p.denumire, ROUND(COALESCE(ps.cantitate,0)::numeric,2) AS stoc
FROM products p
LEFT JOIN product_stocks ps ON ps.product_id = p.id
WHERE p.id = '4a84f6bb-020e-4793-8b78-4b345602a7e6';
