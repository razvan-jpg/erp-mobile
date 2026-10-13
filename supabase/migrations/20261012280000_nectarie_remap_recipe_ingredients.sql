-- NECTARIE: inlocuieste in retete ingredientele BINA (PF fara stoc) cu masterele din baza.
-- CARTOFI (PF 75) → CARTOFI ALBI (351971)
-- SOS CURRY (PF 79) → CURRY (246640)
-- DONER PUI (PF 1318) → PIEPT DE PUI DEZ CU PIELE (6421735000113)
-- Pe retetele VITA / MIXT lipsa carnea de vita BINA: adauga DONER VITA TOCAT (6421735000116)
--   cu cantitatea echivalenta din perechea PUI / linia DONER PUI.
-- Nu modificam in_catalog.

DO $$
DECLARE
  v_company uuid := '10690ba8-f7cf-47a4-8f93-712d69f5e5a2';
  id_cartofi_pf uuid := '568bec7f-f12e-4369-9045-6351d0a2501b';
  id_cartofi_albi uuid := '4a84f6bb-020e-4793-8b78-4b345602a7e6';
  id_sos_curry_pf uuid := 'a4456778-620c-447c-aa71-40346eead460';
  id_curry uuid := 'b2e70ed2-407d-4c48-b221-35c0a915e0d4';
  id_doner_pui_pf uuid := '5585ba74-cc69-4bfe-afc2-0720655255da';
  id_piept uuid := '05d8e20e-5c8b-4815-8303-895941368fb9';
  id_doner_vita uuid := 'b1485b63-748b-45b7-bb08-f93f1caa05ed';
  r record;
  v_qty numeric;
  v_um text;
  v_line int;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.products
    WHERE id = id_cartofi_albi AND company_id = v_company AND cod = '351971'
  ) THEN
    RAISE EXCEPTION 'Master CARTOFI ALBI missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.products
    WHERE id = id_curry AND company_id = v_company AND cod = '246640'
  ) THEN
    RAISE EXCEPTION 'Master CURRY missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.products
    WHERE id = id_piept AND company_id = v_company AND cod = '6421735000113'
  ) THEN
    RAISE EXCEPTION 'Master PIEPT DE PUI missing';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.products
    WHERE id = id_doner_vita AND company_id = v_company AND cod = '6421735000116'
  ) THEN
    RAISE EXCEPTION 'Master DONER VITA TOCAT missing';
  END IF;

  -- 1) CARTOFI PF → CARTOFI ALBI
  DELETE FROM public.product_recipe_lines d
  WHERE d.company_id = v_company
    AND d.ingredient_product_id = id_cartofi_pf
    AND EXISTS (
      SELECT 1 FROM public.product_recipe_lines m
      WHERE m.product_id = d.product_id
        AND m.ingredient_product_id = id_cartofi_albi
    );

  UPDATE public.product_recipe_lines
  SET ingredient_product_id = id_cartofi_albi,
      updated_at = now()
  WHERE company_id = v_company
    AND ingredient_product_id = id_cartofi_pf;

  -- 2) SOS CURRY PF → CURRY
  DELETE FROM public.product_recipe_lines d
  WHERE d.company_id = v_company
    AND d.ingredient_product_id = id_sos_curry_pf
    AND EXISTS (
      SELECT 1 FROM public.product_recipe_lines m
      WHERE m.product_id = d.product_id
        AND m.ingredient_product_id = id_curry
    );

  UPDATE public.product_recipe_lines
  SET ingredient_product_id = id_curry,
      updated_at = now()
  WHERE company_id = v_company
    AND ingredient_product_id = id_sos_curry_pf;

  -- 3) DONER PUI PF → PIEPT (pastreaza cantitatile; pe MIXT e deja jumatate)
  DELETE FROM public.product_recipe_lines d
  WHERE d.company_id = v_company
    AND d.ingredient_product_id = id_doner_pui_pf
    AND EXISTS (
      SELECT 1 FROM public.product_recipe_lines m
      WHERE m.product_id = d.product_id
        AND m.ingredient_product_id = id_piept
    );

  UPDATE public.product_recipe_lines
  SET ingredient_product_id = id_piept,
      updated_at = now()
  WHERE company_id = v_company
    AND ingredient_product_id = id_doner_pui_pf;

  -- 4) Adauga DONER VITA TOCAT pe retetele VITA (fara carne) — cantitate = perechea PUI
  FOR r IN
    SELECT
      vita.id AS vita_id,
      pui_line.cantitate,
      pui_line.unitate_masura,
      pui_line.pret_achizitie,
      pui_line.pret_achizitie_sursa
    FROM public.products vita
    JOIN public.products pui
      ON pui.company_id = vita.company_id
     AND pui.tip = 'produs_finit'
     AND (
       (vita.denumire = 'BOX VITA' AND pui.denumire = 'BOX PUI')
       OR (vita.denumire = 'CHEESE KEBAB VITA' AND pui.denumire = 'CHEESE KEBAB PUI')
       OR (vita.denumire = 'CHIFLA VITA' AND pui.denumire = 'CHIFLA PUI')
       OR (vita.denumire = 'EXTRA CARNE VITA' AND pui.denumire = 'EXTRA CARNE PUI')
       OR (vita.denumire = 'SANDWICH RAPID VITA' AND pui.denumire = 'SANDWICH RAPID PUI')
       OR (vita.denumire = 'SHAORMA FARFURIE VITA' AND pui.denumire = 'SHAORMA FARFURIE PUI')
       OR (vita.denumire = 'SHAORMA MARE VITA' AND pui.denumire = 'SHAORMA MARE PUI')
       OR (vita.denumire = 'SHAORMA MEDIE VITA' AND pui.denumire = 'SHAORMA MEDIE PUI')
       OR (vita.denumire = 'SHAORMAXX  VITA' AND pui.denumire = 'SHAORMAXX  PUI')
       OR (vita.denumire = 'SHAORMAXX FARFURIE VITA' AND pui.denumire = 'SHAORMAXX FARFURIE PUI')
     )
    JOIN public.product_recipe_lines pui_line
      ON pui_line.product_id = pui.id
     AND pui_line.ingredient_product_id = id_piept
    WHERE vita.company_id = v_company
      AND vita.tip = 'produs_finit'
      AND NOT EXISTS (
        SELECT 1 FROM public.product_recipe_lines x
        WHERE x.product_id = vita.id
          AND x.ingredient_product_id = id_doner_vita
      )
  LOOP
    SELECT COALESCE(MAX(numar_linie), 0) + 1 INTO v_line
    FROM public.product_recipe_lines
    WHERE product_id = r.vita_id;

    INSERT INTO public.product_recipe_lines (
      company_id, product_id, ingredient_product_id, numar_linie,
      cantitate, unitate_masura, pret_achizitie, pret_achizitie_sursa
    ) VALUES (
      v_company, r.vita_id, id_doner_vita, v_line,
      r.cantitate, r.unitate_masura, r.pret_achizitie, COALESCE(r.pret_achizitie_sursa, 'local')
    );
  END LOOP;

  -- 5) Pe MIXT: adauga DONER VITA TOCAT cu aceeasi cantitate ca PIEPT (jumatate din portia PUI)
  FOR r IN
    SELECT
      mixt.id AS mixt_id,
      meat.cantitate,
      meat.unitate_masura,
      meat.pret_achizitie,
      meat.pret_achizitie_sursa
    FROM public.products mixt
    JOIN public.product_recipe_lines meat
      ON meat.product_id = mixt.id
     AND meat.ingredient_product_id = id_piept
    WHERE mixt.company_id = v_company
      AND mixt.tip = 'produs_finit'
      AND mixt.denumire ILIKE '%MIXT%'
      AND NOT EXISTS (
        SELECT 1 FROM public.product_recipe_lines x
        WHERE x.product_id = mixt.id
          AND x.ingredient_product_id = id_doner_vita
      )
  LOOP
    SELECT COALESCE(MAX(numar_linie), 0) + 1 INTO v_line
    FROM public.product_recipe_lines
    WHERE product_id = r.mixt_id;

    INSERT INTO public.product_recipe_lines (
      company_id, product_id, ingredient_product_id, numar_linie,
      cantitate, unitate_masura, pret_achizitie, pret_achizitie_sursa
    ) VALUES (
      v_company, r.mixt_id, id_doner_vita, v_line,
      r.cantitate, r.unitate_masura, r.pret_achizitie, COALESCE(r.pret_achizitie_sursa, 'local')
    );
  END LOOP;

  -- 6) Sterge linii reteta al caror ingredient nu mai e rezolvabil (nu ar trebui sa ramana PF nested)
  --    Pastreaza doar daca tipul e materie_prima / marfa / ambalaj / materiale_* / curatenie
  DELETE FROM public.product_recipe_lines prl
  USING public.products ing
  WHERE prl.ingredient_product_id = ing.id
    AND prl.company_id = v_company
    AND ing.tip = 'produs_finit'
    AND ing.id <> prl.product_id;  -- nu sterge self-recipes intentionale; dupa remap nu ar mai fi

  RAISE NOTICE 'NECTARIE recipe ingredient remap done';
END $$;
