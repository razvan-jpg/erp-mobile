-- NECTARIE: PIEPT DE PUI ramane doar in reteta DONER PUI (si, daca exista, crispy/snitel).
-- Pe shaorme / box / chifle / extra carne etc. ingredientul este din nou produsul finit DONER PUI.
-- Nu modificam in_catalog.

DO $$
DECLARE
  v_company uuid := '10690ba8-f7cf-47a4-8f93-712d69f5e5a2';
  id_piept uuid := '05d8e20e-5c8b-4815-8303-895941368fb9';
  id_doner_pui uuid := '5585ba74-cc69-4bfe-afc2-0720655255da';
  v_updated int;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.products
    WHERE id = id_doner_pui AND company_id = v_company AND tip = 'produs_finit'
  ) THEN
    RAISE EXCEPTION 'DONER PUI (produs finit) missing';
  END IF;

  -- Coliziuni: daca o reteta are deja DONER PUI si PIEPT, sterge linia PIEPT (pastreaza DONER)
  DELETE FROM public.product_recipe_lines d
  WHERE d.company_id = v_company
    AND d.ingredient_product_id = id_piept
    AND d.product_id <> id_doner_pui
    AND EXISTS (
      SELECT 1 FROM public.product_recipe_lines m
      WHERE m.product_id = d.product_id
        AND m.ingredient_product_id = id_doner_pui
    );

  -- Pe toate retetele in afara de DONER PUI si crispy/snitel: PIEPT → DONER PUI
  UPDATE public.product_recipe_lines prl
  SET ingredient_product_id = id_doner_pui,
      updated_at = now()
  FROM public.products pf
  WHERE prl.product_id = pf.id
    AND prl.company_id = v_company
    AND prl.ingredient_product_id = id_piept
    AND prl.product_id <> id_doner_pui
    AND pf.denumire NOT ILIKE '%CRISPY%'
    AND pf.denumire NOT ILIKE '%SNITEL%'
    AND pf.denumire NOT ILIKE '%ȘNIȚEL%'
    AND pf.denumire NOT ILIKE '%SNIȚEL%';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  RAISE NOTICE 'Restored DONER PUI on % recipe lines; DONER PUI own recipe keeps PIEPT', v_updated;
END $$;
