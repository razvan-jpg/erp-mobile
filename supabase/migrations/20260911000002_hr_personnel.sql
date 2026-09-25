-- HR: angajați, contracte, stat lunar, pontaj, setări orar/conturi.
-- Acces pe modulul `hr` + societatea selectată (același pattern ca registrul de casă).

CREATE OR REPLACE FUNCTION public.current_user_can_hr_module(p_action TEXT)
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
          AND m.code = 'hr'
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

CREATE OR REPLACE FUNCTION public.current_user_can_access_selected_company_hr_data(
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

    RETURN public.current_user_can_hr_module(p_module_action)
        AND public.current_user_has_company_access(p_company_id, p_company_action);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

CREATE TABLE public.hr_settings (
    company_id UUID PRIMARY KEY REFERENCES public.companies(id) ON DELETE CASCADE,
    schedule JSONB NOT NULL DEFAULT '[]'::jsonb,
    expense_account TEXT NOT NULL DEFAULT '641',
    payable_account TEXT NOT NULL DEFAULT '421',
    cas_account TEXT NOT NULL DEFAULT '431',
    tax_account TEXT NOT NULL DEFAULT '444',
    journal TEXT NOT NULL DEFAULT 'OD',
    first_note_number INTEGER NOT NULL DEFAULT 1 CHECK (first_note_number >= 1),
    one_note_per_employee BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.hr_employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    employee_code TEXT NOT NULL,
    full_name TEXT NOT NULL,
    cnp TEXT,
    iban TEXT,
    phone TEXT,
    default_work_location_id UUID REFERENCES public.company_work_locations(id) ON DELETE SET NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT hr_employees_code_unique UNIQUE (company_id, employee_code)
);

CREATE INDEX idx_hr_employees_company_name
    ON public.hr_employees(company_id, full_name);

CREATE TABLE public.hr_contracts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES public.hr_employees(id) ON DELETE CASCADE,
    contract_type TEXT NOT NULL DEFAULT 'cim',
    job_title TEXT NOT NULL,
    cor_code TEXT,
    work_location_id UUID REFERENCES public.company_work_locations(id) ON DELETE SET NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    hours_per_day NUMERIC(6, 2) NOT NULL DEFAULT 8 CHECK (hours_per_day > 0),
    gross_salary NUMERIC(18, 2) NOT NULL DEFAULT 0 CHECK (gross_salary >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT hr_contracts_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE INDEX idx_hr_contracts_company_employee
    ON public.hr_contracts(company_id, employee_id, start_date DESC);

CREATE TABLE public.hr_payroll_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    year INTEGER NOT NULL CHECK (year BETWEEN 2000 AND 2100),
    month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'ready', 'closed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT hr_payroll_runs_period_unique UNIQUE (company_id, year, month)
);

CREATE INDEX idx_hr_payroll_runs_company_period
    ON public.hr_payroll_runs(company_id, year DESC, month DESC);

CREATE TABLE public.hr_payroll_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id UUID NOT NULL REFERENCES public.hr_payroll_runs(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES public.hr_employees(id) ON DELETE RESTRICT,
    contract_id UUID NOT NULL REFERENCES public.hr_contracts(id) ON DELETE RESTRICT,
    base_hours NUMERIC(8, 2) NOT NULL DEFAULT 0,
    hours_worked NUMERIC(8, 2) NOT NULL DEFAULT 0,
    hours_co NUMERIC(8, 2) NOT NULL DEFAULT 0,
    hours_cm NUMERIC(8, 2) NOT NULL DEFAULT 0,
    days_co NUMERIC(6, 2) NOT NULL DEFAULT 0,
    days_cm NUMERIC(6, 2) NOT NULL DEFAULT 0,
    bonuses NUMERIC(18, 2) NOT NULL DEFAULT 0,
    other_additions NUMERIC(18, 2) NOT NULL DEFAULT 0,
    deductions NUMERIC(18, 2) NOT NULL DEFAULT 0,
    cas_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    gross_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    net_amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    notes TEXT,
    timesheet_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT hr_payroll_lines_unique UNIQUE (run_id, contract_id)
);

CREATE INDEX idx_hr_payroll_lines_run
    ON public.hr_payroll_lines(run_id, employee_id);

CREATE TABLE public.hr_timesheet_days (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id UUID NOT NULL REFERENCES public.hr_payroll_runs(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES public.hr_employees(id) ON DELETE CASCADE,
    work_date DATE NOT NULL,
    start_time TEXT,
    end_time TEXT,
    hours NUMERIC(6, 2) NOT NULL DEFAULT 0,
    kind TEXT NOT NULL CHECK (kind IN ('work', 'co', 'cm', 'rest')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT hr_timesheet_days_unique UNIQUE (run_id, employee_id, work_date)
);

CREATE INDEX idx_hr_timesheet_days_run_employee
    ON public.hr_timesheet_days(run_id, employee_id, work_date);

CREATE TRIGGER hr_settings_updated_at
    BEFORE UPDATE ON public.hr_settings
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER hr_employees_updated_at
    BEFORE UPDATE ON public.hr_employees
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER hr_contracts_updated_at
    BEFORE UPDATE ON public.hr_contracts
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER hr_payroll_runs_updated_at
    BEFORE UPDATE ON public.hr_payroll_runs
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER hr_payroll_lines_updated_at
    BEFORE UPDATE ON public.hr_payroll_lines
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER hr_timesheet_days_updated_at
    BEFORE UPDATE ON public.hr_timesheet_days
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.hr_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_payroll_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_payroll_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hr_timesheet_days ENABLE ROW LEVEL SECURITY;

CREATE POLICY "hr_settings_select" ON public.hr_settings FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'view', 'view'));
CREATE POLICY "hr_settings_insert" ON public.hr_settings FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'create', 'create'));
CREATE POLICY "hr_settings_update" ON public.hr_settings FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'));
CREATE POLICY "hr_settings_delete" ON public.hr_settings FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'delete', 'delete'));

CREATE POLICY "hr_employees_select" ON public.hr_employees FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'view', 'view'));
CREATE POLICY "hr_employees_insert" ON public.hr_employees FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'create', 'create'));
CREATE POLICY "hr_employees_update" ON public.hr_employees FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'));
CREATE POLICY "hr_employees_delete" ON public.hr_employees FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'delete', 'delete'));

CREATE POLICY "hr_contracts_select" ON public.hr_contracts FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'view', 'view'));
CREATE POLICY "hr_contracts_insert" ON public.hr_contracts FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'create', 'create'));
CREATE POLICY "hr_contracts_update" ON public.hr_contracts FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'));
CREATE POLICY "hr_contracts_delete" ON public.hr_contracts FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'delete', 'delete'));

CREATE POLICY "hr_payroll_runs_select" ON public.hr_payroll_runs FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'view', 'view'));
CREATE POLICY "hr_payroll_runs_insert" ON public.hr_payroll_runs FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'create', 'create'));
CREATE POLICY "hr_payroll_runs_update" ON public.hr_payroll_runs FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'));
CREATE POLICY "hr_payroll_runs_delete" ON public.hr_payroll_runs FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'delete', 'delete'));

CREATE POLICY "hr_payroll_lines_select" ON public.hr_payroll_lines FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'view', 'view'));
CREATE POLICY "hr_payroll_lines_insert" ON public.hr_payroll_lines FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'create', 'create'));
CREATE POLICY "hr_payroll_lines_update" ON public.hr_payroll_lines FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'));
CREATE POLICY "hr_payroll_lines_delete" ON public.hr_payroll_lines FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'delete', 'delete'));

CREATE POLICY "hr_timesheet_days_select" ON public.hr_timesheet_days FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'view', 'view'));
CREATE POLICY "hr_timesheet_days_insert" ON public.hr_timesheet_days FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'create', 'create'));
CREATE POLICY "hr_timesheet_days_update" ON public.hr_timesheet_days FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_hr_data(company_id, 'edit', 'edit'));
CREATE POLICY "hr_timesheet_days_delete" ON public.hr_timesheet_days FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_hr_data(company_id, 'delete', 'delete'));
