-- CRM tichete suport: deschise de la client, închise explicit după rezolvare.

CREATE TABLE public.crm_ticket_counters (
    company_id UUID PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
    last_number INTEGER NOT NULL DEFAULT 0 CHECK (last_number >= 0)
);

CREATE OR REPLACE FUNCTION public.crm_next_ticket_number(p_company_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_num INTEGER;
BEGIN
    INSERT INTO public.crm_ticket_counters (company_id, last_number)
    VALUES (p_company_id, 1)
    ON CONFLICT (company_id) DO UPDATE
        SET last_number = public.crm_ticket_counters.last_number + 1
    RETURNING last_number INTO v_num;

    RETURN 'TKT-' || lpad(v_num::text, 5, '0');
END;
$$;

CREATE TABLE public.crm_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    ticket_number TEXT NOT NULL,
    client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE RESTRICT,
    subject TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    priority TEXT NOT NULL DEFAULT 'normal'
        CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    category TEXT NOT NULL DEFAULT 'other'
        CHECK (category IN ('billing', 'delivery', 'technical', 'contract', 'other')),
    assigned_to UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    resolution_notes TEXT,
    resolved_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    opened_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, ticket_number)
);

CREATE TABLE public.crm_ticket_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    ticket_id UUID NOT NULL REFERENCES public.crm_tickets(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_crm_tickets_company ON public.crm_tickets(company_id);
CREATE INDEX idx_crm_tickets_client ON public.crm_tickets(client_id);
CREATE INDEX idx_crm_tickets_status ON public.crm_tickets(status);
CREATE INDEX idx_crm_tickets_updated ON public.crm_tickets(updated_at DESC);
CREATE INDEX idx_crm_ticket_messages_ticket ON public.crm_ticket_messages(ticket_id);
CREATE INDEX idx_crm_ticket_messages_created ON public.crm_ticket_messages(created_at);

CREATE OR REPLACE FUNCTION public.crm_tickets_assign_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.ticket_number IS NULL OR btrim(NEW.ticket_number) = '' THEN
        NEW.ticket_number := public.crm_next_ticket_number(NEW.company_id);
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER crm_tickets_assign_number
    BEFORE INSERT ON public.crm_tickets
    FOR EACH ROW EXECUTE FUNCTION public.crm_tickets_assign_number();

CREATE TRIGGER crm_tickets_updated_at
    BEFORE UPDATE ON public.crm_tickets
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.crm_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_ticket_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "crm_tickets_select" ON public.crm_tickets FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'view', 'view'));

CREATE POLICY "crm_tickets_insert" ON public.crm_tickets FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'create', 'create'));

CREATE POLICY "crm_tickets_update" ON public.crm_tickets FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'));

CREATE POLICY "crm_tickets_delete" ON public.crm_tickets FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'delete', 'delete'));

CREATE POLICY "crm_ticket_messages_select" ON public.crm_ticket_messages FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'view', 'view'));

CREATE POLICY "crm_ticket_messages_insert" ON public.crm_ticket_messages FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'create', 'create'));

CREATE POLICY "crm_ticket_messages_delete" ON public.crm_ticket_messages FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'delete', 'delete'));
