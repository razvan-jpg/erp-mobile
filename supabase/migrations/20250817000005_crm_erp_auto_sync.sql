-- Sincronizare automată CRM ↔ ERP: clienți → companii CRM, utilizatori societate → responsabili CRM.

CREATE UNIQUE INDEX IF NOT EXISTS idx_crm_companies_company_client
    ON public.crm_companies(company_id, client_id)
    WHERE client_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.sync_crm_company_from_client()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        DELETE FROM public.crm_companies WHERE client_id = OLD.id;
        RETURN OLD;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.crm_companies
        WHERE client_id = NEW.id
    ) THEN
        UPDATE public.crm_companies
        SET
            company_id = NEW.company_id,
            name = NEW.denumire,
            cui = NEW.cui,
            email = NEW.email,
            phone = NEW.telefon,
            address = NEW.adresa,
            notes = NEW.observatii,
            updated_at = now()
        WHERE client_id = NEW.id;
    ELSE
        INSERT INTO public.crm_companies (
            company_id, name, cui, email, phone, address, notes, client_id
        )
        VALUES (
            NEW.company_id,
            NEW.denumire,
            NEW.cui,
            NEW.email,
            NEW.telefon,
            NEW.adresa,
            NEW.observatii,
            NEW.id
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS clients_sync_crm_company ON public.clients;
CREATE TRIGGER clients_sync_crm_company
    AFTER INSERT OR UPDATE ON public.clients
    FOR EACH ROW EXECUTE FUNCTION public.sync_crm_company_from_client();

-- Backfill clienți existenți
INSERT INTO public.crm_companies (company_id, name, cui, email, phone, address, notes, client_id)
SELECT
    c.company_id,
    c.denumire,
    c.cui,
    c.email,
    c.telefon,
    c.adresa,
    c.observatii,
    c.id
FROM public.clients c
WHERE NOT EXISTS (
    SELECT 1 FROM public.crm_companies cc WHERE cc.client_id = c.id
);

-- Utilizatori ERP ai societății active (pentru responsabil CRM)
CREATE OR REPLACE FUNCTION public.crm_company_assignable_users(p_company_id UUID)
RETURNS SETOF public.user_profiles
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_company_id IS NULL THEN
        RETURN;
    END IF;

    IF p_company_id IS DISTINCT FROM public.current_user_selected_company_id() THEN
        RETURN;
    END IF;

    IF NOT public.current_user_can_access_selected_company_crm_data(p_company_id, 'view', 'view') THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT up.*
    FROM public.user_profiles up
    INNER JOIN public.user_company_permissions ucp ON ucp.user_id = up.id
    WHERE ucp.company_id = p_company_id
      AND ucp.can_view = true
      AND up.is_blocked = false
      AND COALESCE(up.is_email_confirmed, true) = true
    ORDER BY up.prenume, up.nume;
END;
$$;

GRANT EXECUTE ON FUNCTION public.crm_company_assignable_users(UUID) TO authenticated;
