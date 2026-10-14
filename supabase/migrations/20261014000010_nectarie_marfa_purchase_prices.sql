-- Preț de achiziție pe unitatea de vânzare (bucată / kg), pentru profit și rețete.
-- Nu modifică liniile de factură (acolo prețul poate fi pe cutie sau pe sac).

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS pret_achizitie NUMERIC(14, 4);

COMMENT ON COLUMN public.products.pret_achizitie IS
    'Preț de achiziție pe unitatea de vânzare, pentru profitul de pe tile și pentru rețete. Nu înlocuiește prețul de pe factură.';

CREATE OR REPLACE FUNCTION public.refresh_recipe_purchase_prices(
  p_company_id uuid,
  p_product_ids uuid[] DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_updated int;
  v_pass int := 0;
BEGIN
  IF p_company_id IS NULL THEN
    RETURN;
  END IF;

  PERFORM set_config('erp.refreshing_recipes', '1', true);

  -- Prețul setat pe articol (pe UM de vânzare) are prioritate față de prețul pe cutie/sac din factură.
  UPDATE public.product_recipe_lines prl
  SET pret_achizitie = ing.pret_achizitie,
      pret_achizitie_sursa = 'local',
      updated_at = now()
  FROM public.products ing
  WHERE prl.company_id = p_company_id
    AND prl.ingredient_product_id = ing.id
    AND ing.company_id = p_company_id
    AND ing.pret_achizitie IS NOT NULL
    AND (p_product_ids IS NULL OR ing.id = ANY (p_product_ids))
    AND NOT (
      ing.tip = 'produs_finit'
      AND EXISTS (
        SELECT 1
        FROM public.product_recipe_lines own
        WHERE own.product_id = ing.id
      )
    )
    AND prl.pret_achizitie IS DISTINCT FROM ing.pret_achizitie;

  UPDATE public.product_recipe_lines prl
  SET pret_achizitie = src.pret_unitar,
      pret_achizitie_sursa = 'local',
      updated_at = now()
  FROM (
    SELECT DISTINCT ON (sil.product_id)
      sil.product_id,
      sil.pret_unitar
    FROM public.supplier_invoice_lines sil
    JOIN public.supplier_invoices si ON si.id = sil.invoice_id
    WHERE sil.company_id = p_company_id
      AND sil.product_id IS NOT NULL
      AND sil.pret_unitar IS NOT NULL
      AND (p_product_ids IS NULL OR sil.product_id = ANY (p_product_ids))
    ORDER BY sil.product_id, si.data_factura DESC NULLS LAST, sil.created_at DESC
  ) src
  JOIN public.products ing ON ing.id = src.product_id
  WHERE prl.company_id = p_company_id
    AND prl.ingredient_product_id = src.product_id
    AND ing.pret_achizitie IS NULL
    AND NOT (
      ing.tip = 'produs_finit'
      AND EXISTS (
        SELECT 1
        FROM public.product_recipe_lines own
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
      SELECT ing.id AS product_id,
             (
               SELECT SUM(ROUND(l.cantitate * l.pret_achizitie, 2))
               FROM public.product_recipe_lines l
               WHERE l.product_id = ing.id
                 AND l.pret_achizitie IS NOT NULL
             ) AS cost
      FROM public.products ing
      WHERE ing.company_id = p_company_id
        AND ing.tip = 'produs_finit'
        AND EXISTS (
          SELECT 1
          FROM public.product_recipe_lines own
          WHERE own.product_id = ing.id
        )
    ) costs
    WHERE prl.company_id = p_company_id
      AND prl.ingredient_product_id = costs.product_id
      AND prl.product_id <> costs.product_id
      AND prl.pret_achizitie IS DISTINCT FROM costs.cost;

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    EXIT WHEN v_updated = 0 OR v_pass >= 8;
  END LOOP;

  PERFORM set_config('erp.refreshing_recipes', '0', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_refresh_recipe_prices_from_product_purchase()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_setting('erp.refreshing_recipes', true) = '1' THEN
    RETURN NEW;
  END IF;
  IF NEW.pret_achizitie IS NOT DISTINCT FROM OLD.pret_achizitie THEN
    RETURN NEW;
  END IF;
  IF NEW.company_id IS NOT NULL THEN
    PERFORM public.refresh_recipe_purchase_prices(NEW.company_id, ARRAY[NEW.id]);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS products_refresh_recipe_prices ON public.products;
CREATE TRIGGER products_refresh_recipe_prices
AFTER UPDATE OF pret_achizitie
ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.trg_refresh_recipe_prices_from_product_purchase();

REVOKE ALL ON FUNCTION public.trg_refresh_recipe_prices_from_product_purchase() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.trg_refresh_recipe_prices_from_product_purchase() TO authenticated, service_role;

UPDATE public.products AS p
SET pret_achizitie = v.pret,
    updated_at = now()
FROM (
    VALUES
        ('1480', 5.55),
        ('1478', 5.87),
        ('1481', 4.36),
        ('1479', 4.48),
        ('1482', 3.08),
        ('351971', 3.91)
) AS v(cod, pret)
WHERE p.company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND p.cod = v.cod;

SELECT public.refresh_recipe_purchase_prices('10690ba8-f7cf-47a4-8f93-712d69f5e5a2', NULL);
