-- Permite TVA negativ pe facturi furnizor (ex. note de credit / storno), la fel ca suma_totala.

ALTER TABLE public.supplier_invoices
    DROP CONSTRAINT IF EXISTS supplier_invoices_suma_tva_check;
