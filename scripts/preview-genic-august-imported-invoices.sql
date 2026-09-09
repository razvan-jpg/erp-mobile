-- Preview: facturi importate e-Factura la GENIC, august 2026

SELECT id, denumire, cui
FROM public.companies
WHERE id = '7fe42fd8-a72c-4135-9fba-586ca122ad56'
   OR denumire ILIKE '%genic%';

SELECT
    c.denumire AS societate,
    count(*) FILTER (
        WHERE si.data_factura >= DATE '2026-08-01'
          AND si.data_factura < DATE '2026-09-01'
    ) AS facturi_data_august,
    count(*) FILTER (
        WHERE si.created_at >= TIMESTAMPTZ '2026-08-01'
          AND si.created_at < TIMESTAMPTZ '2026-09-01'
    ) AS facturi_create_august,
    count(*) FILTER (
        WHERE coalesce(si.observatii, '') ILIKE '%import%e-factura%'
           OR coalesce(si.observatii, '') ILIKE '%e-invoice import%'
    ) AS facturi_cu_observatii_import,
    count(*) AS total_facturi_genic
FROM public.supplier_invoices si
JOIN public.companies c ON c.id = si.company_id
WHERE si.company_id IN (
    SELECT id FROM public.companies
    WHERE id = '7fe42fd8-a72c-4135-9fba-586ca122ad56'
       OR denumire ILIKE '%genic%'
)
GROUP BY c.denumire;

SELECT
    si.id,
    si.numar_factura,
    si.data_factura,
    si.created_at::date AS data_import,
    si.suma_totala,
    si.status,
    si.observatii,
    s.denumire AS furnizor,
    (SELECT count(*) FROM public.supplier_nirs n WHERE n.invoice_id = si.id) AS nr_nir,
    (SELECT count(*) FROM public.supplier_payments p WHERE p.invoice_id = si.id) AS nr_plati,
    (SELECT count(*) FROM public.supplier_invoice_credit_offsets o
      WHERE o.credit_invoice_id = si.id OR o.target_invoice_id = si.id) AS nr_storno
FROM public.supplier_invoices si
JOIN public.suppliers s ON s.id = si.supplier_id
WHERE si.company_id IN (
    SELECT id FROM public.companies
    WHERE id = '7fe42fd8-a72c-4135-9fba-586ca122ad56'
       OR denumire ILIKE '%genic%'
)
  AND si.data_factura >= DATE '2026-08-01'
  AND si.data_factura < DATE '2026-09-01'
ORDER BY si.data_factura, s.denumire, si.numar_factura;
