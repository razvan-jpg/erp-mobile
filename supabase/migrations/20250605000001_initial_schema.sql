-- ERP Mobile: initial schema

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Extensible application modules
CREATE TABLE public.modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    sort_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- User profiles extending auth.users
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nume TEXT NOT NULL,
    prenume TEXT NOT NULL,
    cnp TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    telefon TEXT,
    is_admin BOOLEAN NOT NULL DEFAULT false,
    is_blocked BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Granular module permissions per user
CREATE TABLE public.user_module_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    module_id UUID NOT NULL REFERENCES public.modules(id) ON DELETE CASCADE,
    can_view BOOLEAN NOT NULL DEFAULT false,
    can_create BOOLEAN NOT NULL DEFAULT false,
    can_edit BOOLEAN NOT NULL DEFAULT false,
    can_delete BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, module_id)
);

CREATE INDEX idx_user_profiles_is_admin ON public.user_profiles(is_admin);
CREATE INDEX idx_user_profiles_is_blocked ON public.user_profiles(is_blocked);
CREATE INDEX idx_user_module_permissions_user_id ON public.user_module_permissions(user_id);
CREATE INDEX idx_modules_is_active ON public.modules(is_active);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Create profile when auth user is created (metadata from Edge Functions)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (
        id, nume, prenume, cnp, email, telefon, is_admin, is_blocked
    ) VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nume', 'Utilizator'),
        COALESCE(NEW.raw_user_meta_data->>'prenume', 'Nou'),
        COALESCE(NEW.raw_user_meta_data->>'cnp', '0000000000000'),
        NEW.email,
        NEW.raw_user_meta_data->>'telefon',
        COALESCE((NEW.raw_user_meta_data->>'is_admin')::boolean, false),
        COALESCE((NEW.raw_user_meta_data->>'is_blocked')::boolean, false)
    )
    ON CONFLICT (id) DO UPDATE SET
        nume = EXCLUDED.nume,
        prenume = EXCLUDED.prenume,
        cnp = EXCLUDED.cnp,
        email = EXCLUDED.email,
        telefon = EXCLUDED.telefon,
        is_admin = EXCLUDED.is_admin,
        is_blocked = EXCLUDED.is_blocked,
        updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
