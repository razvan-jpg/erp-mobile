-- Costul rețetei se calculează și dacă unele linii nu au preț.
-- La fiecare schimbare de preț pe factura furnizor, prețurile din rețete se actualizează,
-- apoi costul produselor finite urcă în rețetele care le folosesc.

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

CREATE OR REPLACE FUNCTION public.trg_refresh_recipe_prices_from_invoice_line()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF current_setting('erp.refreshing_recipes', true) = '1' THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP IN ('UPDATE', 'DELETE') AND OLD.company_id IS NOT NULL AND OLD.product_id IS NOT NULL THEN
    PERFORM public.refresh_recipe_purchase_prices(OLD.company_id, ARRAY[OLD.product_id]);
  END IF;

  IF TG_OP IN ('INSERT', 'UPDATE')
     AND NEW.company_id IS NOT NULL
     AND NEW.product_id IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.product_id IS DISTINCT FROM OLD.product_id OR NEW.company_id IS DISTINCT FROM OLD.company_id) THEN
    PERFORM public.refresh_recipe_purchase_prices(NEW.company_id, ARRAY[NEW.product_id]);
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_refresh_recipe_prices_from_invoice_date()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ids uuid[];
BEGIN
  IF current_setting('erp.refreshing_recipes', true) = '1' THEN
    RETURN NEW;
  END IF;
  IF NEW.data_factura IS NOT DISTINCT FROM OLD.data_factura THEN
    RETURN NEW;
  END IF;

  SELECT array_agg(DISTINCT sil.product_id)
  INTO v_ids
  FROM public.supplier_invoice_lines sil
  WHERE sil.invoice_id = NEW.id
    AND sil.product_id IS NOT NULL;

  IF v_ids IS NOT NULL THEN
    PERFORM public.refresh_recipe_purchase_prices(NEW.company_id, v_ids);
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_rollup_recipe_cost()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_company uuid;
BEGIN
  IF current_setting('erp.refreshing_recipes', true) = '1' THEN
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    RETURN NEW;
  END IF;

  v_company := COALESCE(NEW.company_id, OLD.company_id);
  IF v_company IS NOT NULL THEN
    PERFORM public.refresh_recipe_purchase_prices(v_company, NULL);
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS supplier_invoice_lines_refresh_recipe_prices ON public.supplier_invoice_lines;
CREATE TRIGGER supplier_invoice_lines_refresh_recipe_prices
AFTER INSERT OR UPDATE OF pret_unitar, product_id, company_id OR DELETE
ON public.supplier_invoice_lines
FOR EACH ROW
EXECUTE FUNCTION public.trg_refresh_recipe_prices_from_invoice_line();

DROP TRIGGER IF EXISTS supplier_invoices_refresh_recipe_prices ON public.supplier_invoices;
CREATE TRIGGER supplier_invoices_refresh_recipe_prices
AFTER UPDATE OF data_factura
ON public.supplier_invoices
FOR EACH ROW
EXECUTE FUNCTION public.trg_refresh_recipe_prices_from_invoice_date();

DROP TRIGGER IF EXISTS product_recipe_lines_rollup_cost ON public.product_recipe_lines;
CREATE TRIGGER product_recipe_lines_rollup_cost
AFTER INSERT OR UPDATE OF cantitate, pret_achizitie, ingredient_product_id OR DELETE
ON public.product_recipe_lines
FOR EACH ROW
EXECUTE FUNCTION public.trg_rollup_recipe_cost();

REVOKE ALL ON FUNCTION public.refresh_recipe_purchase_prices(uuid, uuid[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.trg_refresh_recipe_prices_from_invoice_line() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.trg_refresh_recipe_prices_from_invoice_date() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.trg_rollup_recipe_cost() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.refresh_recipe_purchase_prices(uuid, uuid[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.trg_refresh_recipe_prices_from_invoice_line() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.trg_refresh_recipe_prices_from_invoice_date() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.trg_rollup_recipe_cost() TO authenticated, service_role;

SELECT public.refresh_recipe_purchase_prices(company_id, NULL)
FROM (
  SELECT DISTINCT company_id
  FROM public.product_recipe_lines
) companies;
