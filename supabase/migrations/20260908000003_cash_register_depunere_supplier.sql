-- Depunere în bancă + furnizor pe chitanța de plată.

DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT con.conname
        FROM pg_constraint con
        WHERE con.conrelid = 'public.company_cash_register_entries'::regclass
          AND con.contype = 'c'
          AND pg_get_constraintdef(con.oid) ILIKE '%kind%'
    LOOP
        EXECUTE format('ALTER TABLE public.company_cash_register_entries DROP CONSTRAINT %I', r.conname);
    END LOOP;
END $$;

ALTER TABLE public.company_cash_register_entries
    ADD CONSTRAINT company_cash_register_entries_kind_check
    CHECK (kind IN (
        'incasare_client',
        'plata_furnizor',
        'ridicare_numerar_banca',
        'depunere_banca',
        'incasare_diverse',
        'plata_diverse'
    ));

ALTER TABLE public.company_cash_register_entries
    ADD COLUMN IF NOT EXISTS supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL;

ALTER TABLE public.company_cash_register_entries
    ADD COLUMN IF NOT EXISTS supplier_name TEXT;

CREATE INDEX IF NOT EXISTS idx_company_cash_register_entries_supplier
    ON public.company_cash_register_entries(company_id, supplier_id)
    WHERE supplier_id IS NOT NULL;
