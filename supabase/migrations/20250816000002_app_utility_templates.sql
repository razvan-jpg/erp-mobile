-- Modele globale pentru Utilitare (Z report import, MT940)

CREATE TABLE public.app_utility_templates (
    template_key TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    file_name TEXT NOT NULL,
    content_text TEXT,
    bundle_asset_name TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TRIGGER app_utility_templates_updated_at
    BEFORE UPDATE ON public.app_utility_templates
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.app_utility_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "utility_templates_select" ON public.app_utility_templates
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "utility_templates_superadmin_write" ON public.app_utility_templates
    FOR ALL TO authenticated
    USING (public.is_current_user_superadmin())
    WITH CHECK (public.is_current_user_superadmin());

INSERT INTO public.app_utility_templates (template_key, display_name, file_name, bundle_asset_name)
VALUES
    ('z_report_model', 'Raport Z model', 'Raport_Z_model.pdf', 'Raport_Z_model'),
    ('mt940_model', 'MT940 model', 'MT940_model.txt', 'MT940_model')
ON CONFLICT (template_key) DO NOTHING;
