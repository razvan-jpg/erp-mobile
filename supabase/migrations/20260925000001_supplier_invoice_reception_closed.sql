-- Factură furnizor: închidere manuală a recepției (rest nerecepționat abandonat).
-- Stocul se modifică doar la salvare NIR (sau la ștergerea NIR-ului, care reversează).

ALTER TABLE public.supplier_invoices
    ADD COLUMN IF NOT EXISTS reception_closed BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.supplier_invoices.reception_closed IS
    'True = recepție închisă manual (nu se mai așteaptă restul). Complet recepționată se deduce din NIR-uri.';

CREATE INDEX IF NOT EXISTS idx_supplier_invoices_reception_closed
    ON public.supplier_invoices (company_id, reception_closed)
    WHERE reception_closed = false;
