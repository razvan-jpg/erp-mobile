-- NECTARIE: fara diacritice peste tot (texte societate + module globale UI).
-- Idempotent.

CREATE OR REPLACE FUNCTION private.strip_ro_diacritics(p text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p IS NULL THEN NULL
    ELSE translate(p, 'ăâîșțĂÂÎȘȚşŞţŢ', 'aaistAAISTsStT')
  END;
$$;

DO $$
DECLARE
  v_company uuid := '10690ba8-f7cf-47a4-8f93-712d69f5e5a2';
BEGIN
  -- Produse
  UPDATE public.products SET
    denumire = private.strip_ro_diacritics(denumire),
    descriere = private.strip_ro_diacritics(descriere),
    updated_at = now()
  WHERE company_id = v_company
    AND (
      coalesce(denumire,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]'
      OR coalesce(descriere,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]'
    );

  -- Grupe catalog / meniuri (categorii POS)
  UPDATE public.cm_product_groups SET
    name = private.strip_ro_diacritics(name),
    updated_at = now()
  WHERE company_id = v_company AND coalesce(name,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.cm_menus SET
    name = private.strip_ro_diacritics(name),
    updated_at = now()
  WHERE company_id = v_company AND coalesce(name,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  -- Societate
  UPDATE public.companies SET
    denumire = private.strip_ro_diacritics(denumire),
    adresa = private.strip_ro_diacritics(adresa),
    fiscal_city = private.strip_ro_diacritics(fiscal_city),
    fiscal_county = private.strip_ro_diacritics(fiscal_county),
    fiscal_street = private.strip_ro_diacritics(fiscal_street),
    fiscal_country = private.strip_ro_diacritics(fiscal_country),
    hq_city = private.strip_ro_diacritics(hq_city),
    hq_county = private.strip_ro_diacritics(hq_county),
    hq_street = private.strip_ro_diacritics(hq_street),
    hq_country = private.strip_ro_diacritics(hq_country),
    updated_at = now()
  WHERE id = v_company;

  UPDATE public.company_warehouses SET
    denumire = private.strip_ro_diacritics(denumire),
    adresa = private.strip_ro_diacritics(adresa),
    manager_name = private.strip_ro_diacritics(manager_name),
    additional_info = private.strip_ro_diacritics(additional_info),
    updated_at = now()
  WHERE company_id = v_company
    AND (
      coalesce(denumire,'') || coalesce(adresa,'') || coalesce(manager_name,'') || coalesce(additional_info,'')
    ) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.company_work_locations SET
    denumire = private.strip_ro_diacritics(denumire),
    city = private.strip_ro_diacritics(city),
    county = private.strip_ro_diacritics(county),
    street = private.strip_ro_diacritics(street),
    country = private.strip_ro_diacritics(country),
    updated_at = now()
  WHERE company_id = v_company
    AND (
      coalesce(denumire,'') || coalesce(city,'') || coalesce(county,'') || coalesce(street,'') || coalesce(country,'')
    ) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.suppliers SET
    denumire = private.strip_ro_diacritics(denumire),
    adresa = private.strip_ro_diacritics(adresa),
    observatii = private.strip_ro_diacritics(observatii),
    updated_at = now()
  WHERE company_id = v_company
    AND (coalesce(denumire,'') || coalesce(adresa,'') || coalesce(observatii,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.clients SET
    denumire = private.strip_ro_diacritics(denumire),
    adresa = private.strip_ro_diacritics(adresa),
    observatii = private.strip_ro_diacritics(observatii),
    updated_at = now()
  WHERE company_id = v_company
    AND (coalesce(denumire,'') || coalesce(adresa,'') || coalesce(observatii,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.supplier_invoice_lines sil
  SET denumire = private.strip_ro_diacritics(sil.denumire)
  FROM public.supplier_invoices si
  WHERE si.id = sil.invoice_id AND si.company_id = v_company
    AND coalesce(sil.denumire,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.supplier_invoices
  SET observatii = private.strip_ro_diacritics(observatii), updated_at = now()
  WHERE company_id = v_company AND coalesce(observatii,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.supplier_nir_lines snl
  SET denumire = private.strip_ro_diacritics(snl.denumire)
  FROM public.supplier_nirs sn
  WHERE sn.id = snl.nir_id AND sn.company_id = v_company
    AND coalesce(snl.denumire,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.supplier_payments
  SET observatii = private.strip_ro_diacritics(observatii),
      referinta = private.strip_ro_diacritics(referinta)
  WHERE company_id = v_company
    AND (coalesce(observatii,'') || coalesce(referinta,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.client_invoices
  SET observatii = private.strip_ro_diacritics(observatii), updated_at = now()
  WHERE company_id = v_company AND coalesce(observatii,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.client_payments
  SET observatii = private.strip_ro_diacritics(observatii),
      referinta = private.strip_ro_diacritics(referinta)
  WHERE company_id = v_company
    AND (coalesce(observatii,'') || coalesce(referinta,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.company_fiscal_sale_receipt_lines l
  SET denumire = private.strip_ro_diacritics(l.denumire)
  FROM public.company_fiscal_sale_receipts r
  WHERE r.id = l.receipt_id AND r.company_id = v_company
    AND coalesce(l.denumire,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.company_fiscal_sale_receipts
  SET client_label = private.strip_ro_diacritics(client_label),
      notes = private.strip_ro_diacritics(notes),
      updated_at = now()
  WHERE company_id = v_company
    AND (coalesce(client_label,'') || coalesce(notes,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.company_cash_register_entries
  SET explanation = private.strip_ro_diacritics(explanation),
      supplier_name = private.strip_ro_diacritics(supplier_name),
      updated_at = now()
  WHERE company_id = v_company
    AND (coalesce(explanation,'') || coalesce(supplier_name,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.stock_transfers
  SET observatii = private.strip_ro_diacritics(observatii), updated_at = now()
  WHERE company_id = v_company AND coalesce(observatii,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.production_vouchers
  SET observatii = private.strip_ro_diacritics(observatii), updated_at = now()
  WHERE company_id = v_company AND coalesce(observatii,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.physical_inventories
  SET observatii = private.strip_ro_diacritics(observatii), updated_at = now()
  WHERE company_id = v_company AND coalesce(observatii,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.stock_movements
  SET referinta = private.strip_ro_diacritics(referinta)
  WHERE company_id = v_company AND coalesce(referinta,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  -- CRM
  UPDATE public.crm_companies SET
    name = private.strip_ro_diacritics(name),
    address = private.strip_ro_diacritics(address),
    notes = private.strip_ro_diacritics(notes),
    industry = private.strip_ro_diacritics(industry),
    updated_at = now()
  WHERE company_id = v_company
    AND (coalesce(name,'') || coalesce(address,'') || coalesce(notes,'') || coalesce(industry,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.crm_contacts SET
    first_name = private.strip_ro_diacritics(first_name),
    last_name = private.strip_ro_diacritics(last_name),
    notes = private.strip_ro_diacritics(notes),
    position = private.strip_ro_diacritics(position),
    updated_at = now()
  WHERE company_id = v_company
    AND (coalesce(first_name,'') || coalesce(last_name,'') || coalesce(notes,'') || coalesce(position,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.crm_leads SET
    title = private.strip_ro_diacritics(title),
    contact_name = private.strip_ro_diacritics(contact_name),
    organization_name = private.strip_ro_diacritics(organization_name),
    notes = private.strip_ro_diacritics(notes),
    updated_at = now()
  WHERE company_id = v_company
    AND (coalesce(title,'') || coalesce(contact_name,'') || coalesce(organization_name,'') || coalesce(notes,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.crm_quotes SET
    title = private.strip_ro_diacritics(title),
    notes = private.strip_ro_diacritics(notes),
    updated_at = now()
  WHERE company_id = v_company
    AND (coalesce(title,'') || coalesce(notes,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.crm_quote_lines l
  SET description = private.strip_ro_diacritics(l.description)
  FROM public.crm_quotes q
  WHERE q.id = l.quote_id AND q.company_id = v_company
    AND coalesce(l.description,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.crm_deal_products
  SET description = private.strip_ro_diacritics(description)
  WHERE company_id = v_company AND coalesce(description,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.crm_activities SET
    subject = private.strip_ro_diacritics(subject),
    description = private.strip_ro_diacritics(description),
    updated_at = now()
  WHERE company_id = v_company
    AND (coalesce(subject,'') || coalesce(description,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.crm_tickets SET
    subject = private.strip_ro_diacritics(subject),
    description = private.strip_ro_diacritics(description),
    category = private.strip_ro_diacritics(category),
    resolution_notes = private.strip_ro_diacritics(resolution_notes),
    updated_at = now()
  WHERE company_id = v_company
    AND (
      coalesce(subject,'') || coalesce(description,'') || coalesce(category,'') || coalesce(resolution_notes,'')
    ) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  -- HR
  UPDATE public.hr_employees SET
    full_name = private.strip_ro_diacritics(full_name),
    updated_at = now()
  WHERE company_id = v_company AND coalesce(full_name,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.hr_contracts SET
    job_title = private.strip_ro_diacritics(job_title),
    updated_at = now()
  WHERE company_id = v_company AND coalesce(job_title,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.hr_payroll_lines
  SET notes = private.strip_ro_diacritics(notes),
      timesheet_error = private.strip_ro_diacritics(timesheet_error),
      updated_at = now()
  WHERE company_id = v_company
    AND (coalesce(notes,'') || coalesce(timesheet_error,'')) ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.physical_inventory_lines
  SET observatii = private.strip_ro_diacritics(observatii),
      updated_at = now()
  WHERE company_id = v_company AND coalesce(observatii,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  UPDATE public.inventory_difference_report_lines
  SET denumire = private.strip_ro_diacritics(denumire)
  WHERE company_id = v_company AND coalesce(denumire,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';

  -- Module UI (globale): fara diacritice in denumiri / descrieri
  UPDATE public.modules SET
    name = private.strip_ro_diacritics(name),
    description = private.strip_ro_diacritics(description)
  WHERE coalesce(name,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]'
     OR coalesce(description,'') ~ '[ăâîșțĂÂÎȘȚşŞţŢ]';
END $$;
