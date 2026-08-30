-- Puncte de lucru (Nomenclatoare → Societăți)

CREATE TABLE public.company_work_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    denumire TEXT NOT NULL,
    country TEXT,
    county TEXT,
    city TEXT,
    street TEXT,
    street_number TEXT,
    block TEXT,
    stair TEXT,
    floor TEXT,
    apartment TEXT,
    postal_code TEXT,
    telefon TEXT,
    telefon_mobil TEXT,
    gln TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_default BOOLEAN NOT NULL DEFAULT false,
    operates_at_headquarters BOOLEAN NOT NULL DEFAULT false,
    is_fiscal_domicile BOOLEAN NOT NULL DEFAULT false,
    use_in_declarations BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, denumire)
);

CREATE INDEX idx_company_work_locations_company ON public.company_work_locations(company_id);
CREATE INDEX idx_company_work_locations_active ON public.company_work_locations(company_id, is_active);

CREATE TRIGGER company_work_locations_updated_at
    BEFORE UPDATE ON public.company_work_locations
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.normalize_company_work_location_flags()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT NEW.is_fiscal_domicile THEN
        NEW.use_in_declarations := false;
    END IF;

    IF NEW.is_default THEN
        UPDATE public.company_work_locations
        SET is_default = false, updated_at = now()
        WHERE company_id = NEW.company_id
          AND id IS DISTINCT FROM NEW.id
          AND is_default = true;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER company_work_locations_normalize_flags
    BEFORE INSERT OR UPDATE ON public.company_work_locations
    FOR EACH ROW EXECUTE FUNCTION public.normalize_company_work_location_flags();

CREATE OR REPLACE FUNCTION public.current_user_can_nomenclatoare_module(p_action TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF public.is_current_user_superadmin() THEN
        RETURN true;
    END IF;

    IF public.is_current_user_company_admin() THEN
        RETURN true;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.user_module_permissions ump
        JOIN public.modules m ON m.id = ump.module_id
        WHERE ump.user_id = auth.uid()
          AND m.code = 'nomenclatoare'
          AND m.is_active = true
          AND (
            (p_action = 'view' AND ump.can_view)
            OR (p_action IN ('create', 'insert') AND ump.can_create)
            OR (p_action IN ('edit', 'update') AND ump.can_edit)
            OR (p_action = 'delete' AND ump.can_delete)
          )
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.current_user_can_access_selected_company_nomenclatoare_data(
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

    RETURN public.current_user_can_nomenclatoare_module(p_module_action)
        AND public.current_user_has_company_access(p_company_id, p_company_action);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

ALTER TABLE public.company_work_locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "work_locations_select" ON public.company_work_locations FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view', 'view'));

CREATE POLICY "work_locations_insert" ON public.company_work_locations FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create', 'create'));

CREATE POLICY "work_locations_update" ON public.company_work_locations FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit', 'edit'));

CREATE POLICY "work_locations_delete" ON public.company_work_locations FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete', 'delete'));
