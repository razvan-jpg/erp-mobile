-- Semnal pe linie factură: potrivire produs incertă (de confirmat pe NIR).
ALTER TABLE public.supplier_invoice_lines
    ADD COLUMN IF NOT EXISTS needs_product_review boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.supplier_invoice_lines.needs_product_review IS
    'True when import linked a similar existing product and the user must confirm or create a new sheet on the GRN.';
