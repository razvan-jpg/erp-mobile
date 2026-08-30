INSERT INTO public.app_utility_templates (template_key, display_name, file_name, bundle_asset_name)
VALUES ('registru_casa_model', 'Registru de casa model', 'Registru_Casa_model.pdf', 'Registru_Casa_model')
ON CONFLICT (template_key) DO NOTHING;
