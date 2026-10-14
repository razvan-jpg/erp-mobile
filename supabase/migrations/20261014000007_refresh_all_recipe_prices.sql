-- Recalculeaza pretul fiecarei linii de reteta.
-- Materie prima / marfa / ambalaj: ultimul pret_unitar din facturi.
-- Produs finit folosit ca ingredient: costul propriei retete (cantitate x pret, rotunjit la 2 zecimale).
-- Nu modificam in_catalog.

DO $$
DECLARE
  v_updated int;
  v_pass int := 0;
BEGIN
  UPDATE public.product_recipe_lines prl
  SET pret_achizitie = src.pret_unitar,
      pret_achizitie_sursa = 'local',
      updated_at = now()
  FROM (
    SELECT DISTINCT ON (sil.company_id, sil.product_id)
      sil.company_id,
      sil.product_id,
      sil.pret_unitar
    FROM public.supplier_invoice_lines sil
    JOIN public.supplier_invoices si ON si.id = sil.invoice_id
    ORDER BY sil.company_id, sil.product_id, si.data_factura DESC NULLS LAST, sil.created_at DESC
  ) src
  JOIN public.products ing ON ing.id = src.product_id
  WHERE prl.company_id = src.company_id
    AND prl.ingredient_product_id = src.product_id
    AND NOT (
      ing.tip = 'produs_finit'
      AND EXISTS (
        SELECT 1 FROM public.product_recipe_lines own
        WHERE own.product_id = ing.id
      )
    )
    AND prl.pret_achizitie IS DISTINCT FROM src.pret_unitar;

  LOOP
    v_pass := v_pass + 1;

    UPDATE public.product_recipe_lines prl
    SET pret_achizitie = costs.cost,
        pret_achizitie_sursa = 'local',
        updated_at = now()
    FROM (
      SELECT l.product_id,
             SUM(ROUND(l.cantitate * l.pret_achizitie, 2)) AS cost
      FROM public.product_recipe_lines l
      GROUP BY l.product_id
      HAVING COUNT(*) > 0
         AND COUNT(l.pret_achizitie) = COUNT(*)
    ) costs
    JOIN public.products ing
      ON ing.id = costs.product_id
     AND ing.tip = 'produs_finit'
    WHERE prl.ingredient_product_id = costs.product_id
      AND prl.product_id <> costs.product_id
      AND prl.pret_achizitie IS DISTINCT FROM costs.cost;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    EXIT WHEN v_updated = 0 OR v_pass >= 8;
  END LOOP;
END $$;
