-- CRM: leads (pipeline vânzări) + activități (apeluri, întâlniri, task-uri).
-- Acces: aceleași permisiuni ca modulul Clienți + societatea activă.

CREATE TABLE public.crm_leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    title TEXT NOT NULL,
    organization_name TEXT,
    contact_name TEXT,
    email TEXT,
    phone TEXT,
    cui TEXT,
    source TEXT NOT NULL DEFAULT 'other'
        CHECK (source IN ('website', 'referral', 'phone', 'email', 'event', 'social', 'other')),
    stage TEXT NOT NULL DEFAULT 'new'
        CHECK (stage IN ('new', 'contacted', 'qualified', 'proposal', 'negotiation', 'won', 'lost')),
    estimated_value NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (estimated_value >= 0),
    currency TEXT NOT NULL DEFAULT 'RON',
    probability INTEGER NOT NULL DEFAULT 10 CHECK (probability >= 0 AND probability <= 100),
    expected_close_date DATE,
    client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL,
    notes TEXT,
    assigned_to UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.crm_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    lead_id UUID REFERENCES public.crm_leads(id) ON DELETE CASCADE,
    client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL,
    activity_type TEXT NOT NULL DEFAULT 'task'
        CHECK (activity_type IN ('call', 'meeting', 'email', 'task', 'note')),
    subject TEXT NOT NULL,
    description TEXT,
    due_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_crm_leads_company ON public.crm_leads(company_id);
CREATE INDEX idx_crm_leads_stage ON public.crm_leads(stage);
CREATE INDEX idx_crm_leads_expected_close ON public.crm_leads(expected_close_date);
CREATE INDEX idx_crm_leads_assigned ON public.crm_leads(assigned_to);
CREATE INDEX idx_crm_activities_company ON public.crm_activities(company_id);
CREATE INDEX idx_crm_activities_lead ON public.crm_activities(lead_id);
CREATE INDEX idx_crm_activities_due ON public.crm_activities(due_at);
CREATE INDEX idx_crm_activities_completed ON public.crm_activities(completed_at);

CREATE TRIGGER crm_leads_updated_at
    BEFORE UPDATE ON public.crm_leads
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER crm_activities_updated_at
    BEFORE UPDATE ON public.crm_activities
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.current_user_can_access_selected_company_crm_data(
    p_company_id UUID,
    p_module_action TEXT,
    p_company_action TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_company_id IS NULL THEN
        RETURN false;
    END IF;

    IF p_company_id IS DISTINCT FROM public.current_user_selected_company_id() THEN
        RETURN false;
    END IF;

    RETURN public.current_user_can_client_module(p_module_action)
        AND public.current_user_has_company_access(p_company_id, p_company_action);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

ALTER TABLE public.crm_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "crm_leads_select" ON public.crm_leads FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'view', 'view'));

CREATE POLICY "crm_leads_insert" ON public.crm_leads FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'create', 'create'));

CREATE POLICY "crm_leads_update" ON public.crm_leads FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'));

CREATE POLICY "crm_leads_delete" ON public.crm_leads FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'delete', 'delete'));

CREATE POLICY "crm_activities_select" ON public.crm_activities FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'view', 'view'));

CREATE POLICY "crm_activities_insert" ON public.crm_activities FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'create', 'create'));

CREATE POLICY "crm_activities_update" ON public.crm_activities FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'));

CREATE POLICY "crm_activities_delete" ON public.crm_activities FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'delete', 'delete'));
