-- Cotă TVA (%) pe linii factură furnizor.

ALTER TABLE public.supplier_invoice_lines
    ADD COLUMN IF NOT EXISTS cota_tva NUMERIC(5, 2) NOT NULL DEFAULT 0;

UPDATE public.supplier_invoice_lines
SET cota_tva = ROUND((suma_tva / NULLIF(suma_linie, 0)) * 100, 2)
WHERE suma_linie > 0
  AND suma_tva > 0
  AND cota_tva = 0;
