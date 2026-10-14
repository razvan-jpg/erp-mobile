-- NECTARIE: CEAPA PRAJITA (411271), 0,015 kg, in retetele produselor finite
-- din grupele Farfurii & Box, Sandwich & Chifle si Shaorma.
-- Nu modificam in_catalog.

DO $$
DECLARE
  v_company uuid := '10690ba8-f7cf-47a4-8f93-712d69f5e5a2';
  v_ingredient uuid;
  v_unit text;
  v_price numeric(14, 4);
  v_inserted int;
BEGIN
  SELECT id, unitate_masura
    INTO v_ingredient, v_unit
  FROM public.products
  WHERE company_id = v_company
    AND cod = '411271'
    AND tip = 'materie_prima';

  IF v_ingredient IS NULL THEN
    RAISE EXCEPTION 'CEAPA PRAJITA (411271) missing';
  END IF;

  SELECT sil.pret_unitar
    INTO v_price
  FROM public.supplier_invoice_lines sil
  JOIN public.supplier_invoices si ON si.id = sil.invoice_id
  WHERE sil.company_id = v_company
    AND sil.product_id = v_ingredient
  ORDER BY si.data_factura DESC NULLS LAST, sil.created_at DESC
  LIMIT 1;

  INSERT INTO public.product_recipe_lines (
    company_id, product_id, ingredient_product_id, numar_linie,
    cantitate, unitate_masura, pret_achizitie, pret_achizitie_sursa
  )
  SELECT
    v_company,
    p.id,
    v_ingredient,
    COALESCE((
      SELECT MAX(l.numar_linie)
      FROM public.product_recipe_lines l
      WHERE l.product_id = p.id
    ), 0) + 1,
    0.015,
    v_unit,
    v_price,
    'local'
  FROM public.products p
  WHERE p.company_id = v_company
    AND p.tip = 'produs_finit'
    AND EXISTS (
      SELECT 1
      FROM public.cm_product_group_members m
      JOIN public.cm_product_groups g ON g.id = m.group_id
      WHERE m.product_id = p.id
        AND g.company_id = v_company
        AND g.name IN ('Farfurii & Box', 'Sandwich & Chifle', 'Shaorma')
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.product_recipe_lines x
      WHERE x.product_id = p.id
        AND x.ingredient_product_id = v_ingredient
    );

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  UPDATE public.product_recipe_lines
  SET cantitate = 0.015,
      unitate_masura = v_unit,
      updated_at = now()
  WHERE company_id = v_company
    AND ingredient_product_id = v_ingredient
    AND product_id IN (
      SELECT p.id
      FROM public.products p
      WHERE p.company_id = v_company
        AND p.tip = 'produs_finit'
        AND EXISTS (
          SELECT 1
          FROM public.cm_product_group_members m
          JOIN public.cm_product_groups g ON g.id = m.group_id
          WHERE m.product_id = p.id
            AND g.company_id = v_company
            AND g.name IN ('Farfurii & Box', 'Sandwich & Chifle', 'Shaorma')
        )
    )
    AND cantitate IS DISTINCT FROM 0.015;

  RAISE NOTICE 'CEAPA PRAJITA added on % recipes', v_inserted;
END $$;
