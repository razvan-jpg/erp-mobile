-- Unificare fișe produs duplicate (aceeași denumire) pe NECTARIE.
-- Master = cea mai veche fișă; stocurile se adună; referințele se mută; duplicatele se șterg.

DO $$
DECLARE
  pairs CONSTANT uuid[][] := ARRAY[
    ARRAY['2d2d5ab2-3809-455b-a9c3-6f1aee0e06e1'::uuid, '88b4ddbe-347d-4032-ac27-6fe376d5d57b'::uuid], -- ardei iute
    ARRAY['2cc77618-287c-435a-95b6-a200afef3c40'::uuid, 'e03a3ff9-1570-4a64-bff5-80e03fa49967'::uuid]  -- CASTRAVETI MURATI
  ];
  master_id uuid;
  dup_id uuid;
  i int;
BEGIN
  FOR i IN 1 .. array_length(pairs, 1) LOOP
    master_id := pairs[i][1];
    dup_id := pairs[i][2];

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

    -- warehouse stocks: adună pe aceeași gestiune, apoi șterge duplicatul
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
        WHERE w.company_id = d.company_id
          AND w.warehouse_id = d.warehouse_id
          AND w.product_id = master_id
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
      AND NOT EXISTS (
        SELECT 1 FROM product_stocks m WHERE m.product_id = master_id AND m.company_id = d.company_id
      );

    DELETE FROM product_stocks WHERE product_id = dup_id;
    DELETE FROM products WHERE id = dup_id;
  END LOOP;
END $$;

SELECT p.denumire, ROUND(COALESCE(ps.cantitate,0)::numeric,2) AS stoc, p.id
FROM products p
LEFT JOIN product_stocks ps ON ps.product_id = p.id
WHERE p.id IN (
  '2d2d5ab2-3809-455b-a9c3-6f1aee0e06e1',
  '2cc77618-287c-435a-95b6-a200afef3c40'
)
OR (p.company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
    AND lower(trim(p.denumire)) IN ('ardei iute','castraveti murati'));
