-- CRM extins (Bitrix24-style): companii CRM, contacte, lead-uri, produse pe tranzacție, oferte.

CREATE TABLE public.crm_companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    cui TEXT,
    email TEXT,
    phone TEXT,
    website TEXT,
    address TEXT,
    industry TEXT,
    notes TEXT,
    client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL,
    assigned_to UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.crm_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    crm_company_id UUID REFERENCES public.crm_companies(id) ON DELETE SET NULL,
    first_name TEXT NOT NULL DEFAULT '',
    last_name TEXT NOT NULL DEFAULT '',
    email TEXT,
    phone TEXT,
    position TEXT,
    notes TEXT,
    client_id UUID REFERENCES public.clients(id) ON DELETE SET NULL,
    assigned_to UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.crm_leads
    ADD COLUMN IF NOT EXISTS pipeline_type TEXT NOT NULL DEFAULT 'deal'
        CHECK (pipeline_type IN ('lead', 'deal'));

ALTER TABLE public.crm_leads
    ADD COLUMN IF NOT EXISTS crm_company_id UUID REFERENCES public.crm_companies(id) ON DELETE SET NULL;

ALTER TABLE public.crm_leads
    ADD COLUMN IF NOT EXISTS crm_contact_id UUID REFERENCES public.crm_contacts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_crm_leads_pipeline_type ON public.crm_leads(pipeline_type);
CREATE INDEX IF NOT EXISTS idx_crm_companies_company ON public.crm_companies(company_id);
CREATE INDEX IF NOT EXISTS idx_crm_contacts_company ON public.crm_contacts(company_id);
CREATE INDEX IF NOT EXISTS idx_crm_contacts_crm_company ON public.crm_contacts(crm_company_id);

CREATE TABLE public.crm_deal_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    lead_id UUID NOT NULL REFERENCES public.crm_leads(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    quantity NUMERIC(14, 3) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
    discount_percent NUMERIC(5, 2) NOT NULL DEFAULT 0
        CHECK (discount_percent >= 0 AND discount_percent <= 100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_crm_deal_products_lead ON public.crm_deal_products(lead_id);

CREATE TABLE public.crm_quote_counters (
    company_id UUID PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
    last_number INTEGER NOT NULL DEFAULT 0 CHECK (last_number >= 0)
);

CREATE OR REPLACE FUNCTION public.crm_next_quote_number(p_company_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_num INTEGER;
BEGIN
    INSERT INTO public.crm_quote_counters (company_id, last_number)
    VALUES (p_company_id, 1)
    ON CONFLICT (company_id) DO UPDATE
        SET last_number = public.crm_quote_counters.last_number + 1
    RETURNING last_number INTO v_num;

    RETURN 'OF-' || lpad(v_num::text, 5, '0');
END;
$$;

CREATE TABLE public.crm_quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    lead_id UUID REFERENCES public.crm_leads(id) ON DELETE SET NULL,
    crm_company_id UUID REFERENCES public.crm_companies(id) ON DELETE SET NULL,
    crm_contact_id UUID REFERENCES public.crm_contacts(id) ON DELETE SET NULL,
    quote_number TEXT NOT NULL DEFAULT '',
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'sent', 'accepted', 'rejected')),
    valid_until DATE,
    notes TEXT,
    total_amount NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    currency TEXT NOT NULL DEFAULT 'RON',
    assigned_to UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, quote_number)
);

CREATE TABLE public.crm_quote_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE RESTRICT,
    quote_id UUID NOT NULL REFERENCES public.crm_quotes(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    quantity NUMERIC(14, 3) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
    discount_percent NUMERIC(5, 2) NOT NULL DEFAULT 0
        CHECK (discount_percent >= 0 AND discount_percent <= 100),
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_crm_quotes_company ON public.crm_quotes(company_id);
CREATE INDEX idx_crm_quotes_lead ON public.crm_quotes(lead_id);
CREATE INDEX idx_crm_quote_lines_quote ON public.crm_quote_lines(quote_id);

CREATE OR REPLACE FUNCTION public.crm_quotes_assign_number()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.quote_number IS NULL OR btrim(NEW.quote_number) = '' THEN
        NEW.quote_number := public.crm_next_quote_number(NEW.company_id);
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER crm_quotes_assign_number
    BEFORE INSERT ON public.crm_quotes
    FOR EACH ROW EXECUTE FUNCTION public.crm_quotes_assign_number();

CREATE TRIGGER crm_companies_updated_at
    BEFORE UPDATE ON public.crm_companies
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER crm_contacts_updated_at
    BEFORE UPDATE ON public.crm_contacts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER crm_quotes_updated_at
    BEFORE UPDATE ON public.crm_quotes
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.crm_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_deal_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_quote_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "crm_companies_select" ON public.crm_companies FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'view', 'view'));
CREATE POLICY "crm_companies_insert" ON public.crm_companies FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'create', 'create'));
CREATE POLICY "crm_companies_update" ON public.crm_companies FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'));
CREATE POLICY "crm_companies_delete" ON public.crm_companies FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'delete', 'delete'));

CREATE POLICY "crm_contacts_select" ON public.crm_contacts FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'view', 'view'));
CREATE POLICY "crm_contacts_insert" ON public.crm_contacts FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'create', 'create'));
CREATE POLICY "crm_contacts_update" ON public.crm_contacts FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'));
CREATE POLICY "crm_contacts_delete" ON public.crm_contacts FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'delete', 'delete'));

CREATE POLICY "crm_deal_products_select" ON public.crm_deal_products FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'view', 'view'));
CREATE POLICY "crm_deal_products_insert" ON public.crm_deal_products FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'create', 'create'));
CREATE POLICY "crm_deal_products_update" ON public.crm_deal_products FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'));
CREATE POLICY "crm_deal_products_delete" ON public.crm_deal_products FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'delete', 'delete'));

CREATE POLICY "crm_quotes_select" ON public.crm_quotes FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'view', 'view'));
CREATE POLICY "crm_quotes_insert" ON public.crm_quotes FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'create', 'create'));
CREATE POLICY "crm_quotes_update" ON public.crm_quotes FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'));
CREATE POLICY "crm_quotes_delete" ON public.crm_quotes FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'delete', 'delete'));

CREATE POLICY "crm_quote_lines_select" ON public.crm_quote_lines FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'view', 'view'));
CREATE POLICY "crm_quote_lines_insert" ON public.crm_quote_lines FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'create', 'create'));
CREATE POLICY "crm_quote_lines_update" ON public.crm_quote_lines FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_crm_data(company_id, 'edit', 'edit'));
CREATE POLICY "crm_quote_lines_delete" ON public.crm_quote_lines FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_crm_data(company_id, 'delete', 'delete'));
