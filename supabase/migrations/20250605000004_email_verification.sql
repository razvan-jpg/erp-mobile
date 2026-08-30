-- Email verification: cont activ doar după confirmarea adresei

ALTER TABLE public.user_profiles
ADD COLUMN IF NOT EXISTS is_email_confirmed BOOLEAN NOT NULL DEFAULT false;

-- Utilizatorii existenți cu email deja confirmat în auth
UPDATE public.user_profiles p
SET is_email_confirmed = true
FROM auth.users u
WHERE p.id = u.id AND u.email_confirmed_at IS NOT NULL;

-- Sincronizare la creare profil
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (
        id, nume, prenume, cnp, email, telefon, is_admin, is_blocked, is_email_confirmed
    ) VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nume', 'Utilizator'),
        COALESCE(NEW.raw_user_meta_data->>'prenume', 'Nou'),
        COALESCE(NEW.raw_user_meta_data->>'cnp', '0000000000000'),
        NEW.email,
        NEW.raw_user_meta_data->>'telefon',
        COALESCE((NEW.raw_user_meta_data->>'is_admin')::boolean, false),
        COALESCE((NEW.raw_user_meta_data->>'is_blocked')::boolean, false),
        NEW.email_confirmed_at IS NOT NULL
    )
    ON CONFLICT (id) DO UPDATE SET
        nume = EXCLUDED.nume,
        prenume = EXCLUDED.prenume,
        cnp = EXCLUDED.cnp,
        email = EXCLUDED.email,
        telefon = EXCLUDED.telefon,
        is_admin = EXCLUDED.is_admin,
        is_blocked = EXCLUDED.is_blocked,
        is_email_confirmed = EXCLUDED.is_email_confirmed,
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Sincronizare când utilizatorul confirmă emailul
CREATE OR REPLACE FUNCTION public.sync_email_confirmed()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.email_confirmed_at IS NOT NULL
       AND (OLD.email_confirmed_at IS NULL OR OLD.email_confirmed_at IS DISTINCT FROM NEW.email_confirmed_at) THEN
        UPDATE public.user_profiles
        SET is_email_confirmed = true, updated_at = now()
        WHERE id = NEW.id;
    ELSIF NEW.email_confirmed_at IS NULL AND OLD.email_confirmed_at IS NOT NULL THEN
        UPDATE public.user_profiles
        SET is_email_confirmed = false, updated_at = now()
        WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_email_confirmed ON auth.users;
CREATE TRIGGER on_auth_user_email_confirmed
    AFTER UPDATE OF email_confirmed_at ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.sync_email_confirmed();
