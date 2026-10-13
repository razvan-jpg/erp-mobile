-- Tokenurile SPV (OAuth ANAF) și înrolarea aplicației stau doar pe server.
-- Aplicația vede starea în company_efactura_settings, fără access token.

CREATE TABLE IF NOT EXISTS public.anaf_oauth_app (
    id SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    client_id TEXT NOT NULL,
    client_secret TEXT NOT NULL,
    redirect_uri TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.anaf_oauth_states (
    state UUID PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS public.anaf_oauth_invites (
    token UUID PRIMARY KEY,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    invited_by UUID NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.company_anaf_tokens (
    company_id UUID PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
    access_token TEXT NOT NULL,
    refresh_token TEXT NOT NULL,
    access_expires_at TIMESTAMPTZ NOT NULL,
    refresh_expires_at TIMESTAMPTZ NOT NULL,
    authorized_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.anaf_oauth_app IS
    'O singură aplicație OAuth înregistrată la ANAF pentru ERP Mobile. Doar service_role.';
COMMENT ON TABLE public.company_anaf_tokens IS
    'Access token și refresh token SPV, pe societate. Doar service_role.';
COMMENT ON TABLE public.anaf_oauth_invites IS
    'Linkul de autorizare trimis contabilului, valabil 7 zile. Doar service_role.';
COMMENT ON COLUMN public.company_efactura_settings.auth_valid_until IS
    'Ziua până la care access token-ul SPV este valabil, inclusiv.';

ALTER TABLE public.company_efactura_settings
    ADD COLUMN IF NOT EXISTS auth_invite_sent_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS auth_invite_expires_at TIMESTAMPTZ;

ALTER TABLE public.anaf_oauth_app ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anaf_oauth_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.anaf_oauth_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_anaf_tokens ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.anaf_oauth_app FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.anaf_oauth_states FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.anaf_oauth_invites FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.company_anaf_tokens FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.anaf_oauth_app TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.anaf_oauth_states TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.anaf_oauth_invites TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.company_anaf_tokens TO service_role;
