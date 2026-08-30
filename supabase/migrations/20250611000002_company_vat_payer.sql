-- Plătitor TVA pe fișa societății.

ALTER TABLE public.companies
    ADD COLUMN IF NOT EXISTS platitor_tva BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.companies.platitor_tva IS 'Societate plătitoare de TVA (0%, 11%, 21% pe articole).';
