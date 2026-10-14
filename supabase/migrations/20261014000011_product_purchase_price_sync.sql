-- Prețul de achiziție de pe fișa articolului (fără TVA, pe UM de stoc)
-- se actualizează la fiecare factură furnizor și la fiecare NIR.
-- Nu rescrie prețurile deja setate până la următoarea cumpărare.

CREATE OR REPLACE FUNCTION public.erp_unit_key(p_unit text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT lower(trim(both ' .' FROM coalesce(p_unit, '')));
$$;

CREATE OR REPLACE FUNCTION public.sync_product_purchase_price(
  p_company_id uuid,
  p_product_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stock_unit text;
  v_factor numeric;
  v_nir_price numeric;
  v_nir_date date;
  v_inv_price numeric;
  v_inv_date date;
  v_price numeric;
BEGIN
  IF p_company_id IS NULL OR p_product_id IS NULL THEN
    RETURN;
  END IF;
  IF current_setting('erp.refreshing_recipes', true) = '1' THEN
    RETURN;
  END IF;

  SELECT unitate_masura, COALESCE(factor_conversie, 1)
  INTO v_stock_unit, v_factor
  FROM public.products
  WHERE id = p_product_id
    AND company_id = p_company_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT nl.pret_unitar, COALESCE(si.data_factura, sn.data_nir)
  INTO v_nir_price, v_nir_date
  FROM public.supplier_nir_lines nl
  JOIN public.supplier_nirs sn ON sn.id = nl.nir_id
  LEFT JOIN public.supplier_invoices si ON si.id = sn.invoice_id
  WHERE nl.company_id = p_company_id
    AND nl.product_id = p_product_id
    AND nl.cantitate > 0
    AND nl.pret_unitar IS NOT NULL
  ORDER BY COALESCE(si.data_factura, sn.data_nir) DESC NULLS LAST, nl.created_at DESC
  LIMIT 1;

  SELECT
    CASE
      WHEN sil.cantitate > 0 AND conv.factor > 0
        THEN ROUND(sil.suma_linie / (sil.cantitate * conv.factor), 4)
      ELSE sil.pret_unitar
    END,
    si.data_factura
  INTO v_inv_price, v_inv_date
  FROM public.supplier_invoice_lines sil
  JOIN public.supplier_invoices si ON si.id = sil.invoice_id
  CROSS JOIN LATERAL (
    SELECT CASE
      WHEN public.erp_unit_key(sil.unitate_masura) = public.erp_unit_key(v_stock_unit) THEN 1
      WHEN COALESCE(v_factor, 1) > 1 THEN v_factor
      ELSE 1
    END AS factor
  ) conv
  WHERE sil.company_id = p_company_id
    AND sil.product_id = p_product_id
    AND sil.cantitate > 0
    AND sil.pret_unitar IS NOT NULL
  ORDER BY si.data_factura DESC NULLS LAST, sil.created_at DESC
  LIMIT 1;

  IF v_nir_price IS NOT NULL
     AND (v_inv_date IS NULL OR v_nir_date IS NULL OR v_nir_date >= v_inv_date) THEN
    v_price := v_nir_price;
  ELSIF v_inv_price IS NOT NULL THEN
    v_price := v_inv_price;
  ELSE
    RETURN;
  END IF;

  UPDATE public.products
  SET pret_achizitie = v_price,
      updated_at = now()
  WHERE id = p_product_id
    AND company_id = p_company_id
    AND pret_achizitie IS DISTINCT FROM v_price;
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
    PERFORM public.sync_product_purchase_price(OLD.company_id, OLD.product_id);
    PERFORM public.refresh_recipe_purchase_prices(OLD.company_id, ARRAY[OLD.product_id]);
  END IF;

  IF TG_OP = 'INSERT' AND NEW.company_id IS NOT NULL AND NEW.product_id IS NOT NULL THEN
    PERFORM public.sync_product_purchase_price(NEW.company_id, NEW.product_id);
    PERFORM public.refresh_recipe_purchase_prices(NEW.company_id, ARRAY[NEW.product_id]);
  ELSIF TG_OP = 'UPDATE'
     AND NEW.company_id IS NOT NULL
     AND NEW.product_id IS NOT NULL
     AND (
       NEW.product_id IS DISTINCT FROM OLD.product_id
       OR NEW.company_id IS DISTINCT FROM OLD.company_id
       OR NEW.pret_unitar IS DISTINCT FROM OLD.pret_unitar
       OR NEW.cantitate IS DISTINCT FROM OLD.cantitate
       OR NEW.suma_linie IS DISTINCT FROM OLD.suma_linie
     ) THEN
    PERFORM public.sync_product_purchase_price(NEW.company_id, NEW.product_id);
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
  v_id uuid;
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
    FOREACH v_id IN ARRAY v_ids LOOP
      PERFORM public.sync_product_purchase_price(NEW.company_id, v_id);
    END LOOP;
    PERFORM public.refresh_recipe_purchase_prices(NEW.company_id, v_ids);
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_sync_purchase_price_from_nir()
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
    PERFORM public.sync_product_purchase_price(OLD.company_id, OLD.product_id);
  END IF;

  IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.company_id IS NOT NULL AND NEW.product_id IS NOT NULL THEN
    PERFORM public.sync_product_purchase_price(NEW.company_id, NEW.product_id);
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS supplier_invoice_lines_refresh_recipe_prices ON public.supplier_invoice_lines;
CREATE TRIGGER supplier_invoice_lines_refresh_recipe_prices
AFTER INSERT OR UPDATE OF pret_unitar, cantitate, suma_linie, product_id, company_id OR DELETE
ON public.supplier_invoice_lines
FOR EACH ROW
EXECUTE FUNCTION public.trg_refresh_recipe_prices_from_invoice_line();

DROP TRIGGER IF EXISTS supplier_nir_lines_sync_purchase_price ON public.supplier_nir_lines;
CREATE TRIGGER supplier_nir_lines_sync_purchase_price
AFTER INSERT OR UPDATE OF pret_unitar, cantitate, suma_linie, product_id, company_id OR DELETE
ON public.supplier_nir_lines
FOR EACH ROW
EXECUTE FUNCTION public.trg_sync_purchase_price_from_nir();

REVOKE ALL ON FUNCTION public.erp_unit_key(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.sync_product_purchase_price(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.trg_sync_purchase_price_from_nir() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.erp_unit_key(text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sync_product_purchase_price(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.trg_sync_purchase_price_from_nir() TO authenticated, service_role;
