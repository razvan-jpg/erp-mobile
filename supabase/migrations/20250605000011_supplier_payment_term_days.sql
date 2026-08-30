-- Termen de plată furnizor (zile până la scadență, pentru calcul automat la facturi)

ALTER TABLE public.suppliers
    ADD COLUMN IF NOT EXISTS nr_zile_scadenta INTEGER NOT NULL DEFAULT 0
    CHECK (nr_zile_scadenta >= 0);

COMMENT ON COLUMN public.suppliers.nr_zile_scadenta IS
    'Număr zile de la data facturii până la scadență (0 = fără calcul automat).';
