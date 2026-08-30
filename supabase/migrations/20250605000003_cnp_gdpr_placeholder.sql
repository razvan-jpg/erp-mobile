-- Permite CNP placeholder GDPR (0000000000000) pentru mai mulți utilizatori.
-- CNP-urile reale rămân unice.

ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_cnp_key;

DROP INDEX IF EXISTS user_profiles_cnp_unique_real;

CREATE UNIQUE INDEX user_profiles_cnp_unique_real
    ON public.user_profiles (cnp)
    WHERE cnp <> '0000000000000';
