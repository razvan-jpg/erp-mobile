-- Contacte CRM sincronizate automat din clienții ERP (email, telefon, legătură companie CRM).

CREATE UNIQUE INDEX IF NOT EXISTS idx_crm_contacts_company_client
    ON public.crm_contacts(company_id, client_id)
    WHERE client_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.sync_crm_contact_from_client()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_crm_company_id UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN
        DELETE FROM public.crm_contacts WHERE client_id = OLD.id;
        RETURN OLD;
    END IF;

    SELECT id INTO v_crm_company_id
    FROM public.crm_companies
    WHERE client_id = NEW.id
    LIMIT 1;

    IF EXISTS (
        SELECT 1 FROM public.crm_contacts WHERE client_id = NEW.id
    ) THEN
        UPDATE public.crm_contacts
        SET
            company_id = NEW.company_id,
            crm_company_id = v_crm_company_id,
            first_name = '',
            last_name = NEW.denumire,
            email = NEW.email,
            phone = NEW.telefon,
            position = 'Contact principal',
            notes = NEW.observatii,
            updated_at = now()
        WHERE client_id = NEW.id;
    ELSE
        INSERT INTO public.crm_contacts (
            company_id,
            crm_company_id,
            first_name,
            last_name,
            email,
            phone,
            position,
            notes,
            client_id
        )
        VALUES (
            NEW.company_id,
            v_crm_company_id,
            '',
            NEW.denumire,
            NEW.email,
            NEW.telefon,
            'Contact principal',
            NEW.observatii,
            NEW.id
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS clients_sync_crm_contact ON public.clients;
CREATE TRIGGER clients_sync_crm_contact
    AFTER INSERT OR UPDATE ON public.clients
    FOR EACH ROW EXECUTE FUNCTION public.sync_crm_contact_from_client();

-- Backfill contacte pentru clienții existenți
INSERT INTO public.crm_contacts (
    company_id,
    crm_company_id,
    first_name,
    last_name,
    email,
    phone,
    position,
    notes,
    client_id
)
SELECT
    c.company_id,
    cc.id,
    '',
    c.denumire,
    c.email,
    c.telefon,
    'Contact principal',
    c.observatii,
    c.id
FROM public.clients c
LEFT JOIN public.crm_companies cc ON cc.client_id = c.id
WHERE NOT EXISTS (
    SELECT 1 FROM public.crm_contacts ct WHERE ct.client_id = c.id
);

-- Re-sincronizează contactele existente (actualizează legătura la companie CRM)
UPDATE public.crm_contacts ct
SET
    crm_company_id = cc.id,
    last_name = c.denumire,
    email = c.email,
    phone = c.telefon,
    notes = c.observatii,
    updated_at = now()
FROM public.clients c
LEFT JOIN public.crm_companies cc ON cc.client_id = c.id
WHERE ct.client_id = c.id;
