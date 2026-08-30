-- Limba de afișare preferată per utilizator
ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS preferred_language_code TEXT NOT NULL DEFAULT 'ro';

ALTER TABLE public.user_profiles
    DROP CONSTRAINT IF EXISTS user_profiles_preferred_language_code_check;

ALTER TABLE public.user_profiles
    ADD CONSTRAINT user_profiles_preferred_language_code_check
    CHECK (preferred_language_code IN (
        'ro', 'en', 'fr', 'it', 'es', 'de', 'pl', 'cs', 'sr', 'hu',
        'ru', 'bg', 'tr', 'ne', 'ko', 'zh-Hans', 'ja', 'ar', 'th', 'nl'
    ));

COMMENT ON COLUMN public.user_profiles.preferred_language_code IS
    'Limba UI preferată (BCP-47): ro, en, fr, it, es, de, pl, cs, sr, hu, ru, bg, tr, ne, ko, zh-Hans, ja, ar, th, nl';
