-- NECTARIE: denumiri / texte fără diacritice (ăâîșț → aaist).
-- Idempotent.

DO $$
DECLARE
  v_company uuid := '10690ba8-f7cf-47a4-8f93-712d69f5e5a2';
  v_from text := 'ăâîșțĂÂÎȘȚşŞţŢ';
  v_to   text := 'aaistAAISTsStT';
BEGIN
  UPDATE public.products
  SET denumire = translate(denumire, v_from, v_to), updated_at = now()
  WHERE company_id = v_company AND denumire ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.companies
  SET
    denumire = translate(denumire, v_from, v_to),
    adresa = translate(adresa, v_from, v_to),
    fiscal_city = translate(fiscal_city, v_from, v_to),
    fiscal_county = translate(fiscal_county, v_from, v_to),
    fiscal_street = translate(fiscal_street, v_from, v_to),
    fiscal_country = translate(fiscal_country, v_from, v_to),
    hq_city = translate(hq_city, v_from, v_to),
    hq_county = translate(hq_county, v_from, v_to),
    hq_street = translate(hq_street, v_from, v_to),
    hq_country = translate(hq_country, v_from, v_to),
    updated_at = now()
  WHERE id = v_company;

  UPDATE public.company_warehouses
  SET denumire = translate(denumire, v_from, v_to), updated_at = now()
  WHERE company_id = v_company AND denumire ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.company_work_locations
  SET denumire = translate(denumire, v_from, v_to), updated_at = now()
  WHERE company_id = v_company AND denumire ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.suppliers
  SET denumire = translate(denumire, v_from, v_to), updated_at = now()
  WHERE company_id = v_company AND denumire ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.clients
  SET denumire = translate(denumire, v_from, v_to), updated_at = now()
  WHERE company_id = v_company AND denumire ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.cm_product_groups
  SET name = translate(name, v_from, v_to), updated_at = now()
  WHERE company_id = v_company AND name ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.cm_menus
  SET name = translate(name, v_from, v_to), updated_at = now()
  WHERE company_id = v_company AND name ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.supplier_invoice_lines sil
  SET denumire = translate(sil.denumire, v_from, v_to)
  FROM public.supplier_invoices si
  WHERE si.id = sil.invoice_id
    AND si.company_id = v_company
    AND sil.denumire ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.supplier_nir_lines snl
  SET denumire = translate(snl.denumire, v_from, v_to)
  FROM public.supplier_nirs sn
  WHERE sn.id = snl.nir_id
    AND sn.company_id = v_company
    AND snl.denumire ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.stock_transfers
  SET observatii = translate(observatii, v_from, v_to), updated_at = now()
  WHERE company_id = v_company AND coalesce(observatii, '') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.production_vouchers
  SET observatii = translate(observatii, v_from, v_to), updated_at = now()
  WHERE company_id = v_company AND coalesce(observatii, '') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';
END $$;
