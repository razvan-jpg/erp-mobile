-- Faster invoice / NIR / product lookups for list filters and import.

CREATE INDEX IF NOT EXISTS idx_supplier_invoices_company_created
    ON public.supplier_invoices (company_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_supplier_invoices_company_data_factura
    ON public.supplier_invoices (company_id, data_factura DESC);

CREATE INDEX IF NOT EXISTS idx_supplier_invoices_company_number
    ON public.supplier_invoices (company_id, numar_factura);

CREATE INDEX IF NOT EXISTS idx_client_invoices_company_created
    ON public.client_invoices (company_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_client_invoices_company_data_factura
    ON public.client_invoices (company_id, data_factura DESC);

CREATE INDEX IF NOT EXISTS idx_supplier_nirs_company_invoice
    ON public.supplier_nirs (company_id, invoice_id);

CREATE INDEX IF NOT EXISTS idx_supplier_nir_lines_nir
    ON public.supplier_nir_lines (nir_id);

CREATE INDEX IF NOT EXISTS idx_supplier_invoice_lines_invoice
    ON public.supplier_invoice_lines (invoice_id);

CREATE INDEX IF NOT EXISTS idx_products_company_active
    ON public.products (company_id)
    WHERE is_active = true;

ANALYZE public.supplier_invoices;
ANALYZE public.client_invoices;
ANALYZE public.supplier_nirs;
ANALYZE public.supplier_nir_lines;
ANALYZE public.supplier_invoice_lines;
ANALYZE public.products;
ANALYZE public.suppliers;
