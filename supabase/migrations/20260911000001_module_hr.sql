-- Modul ERP: HR (personal). Tile pe dashboard; implementare funcțională ulterioară.

INSERT INTO public.modules (code, name, description, sort_order)
VALUES (
    'hr',
    'HR',
    'Resurse umane: personal, contracte și evidențe angajați pentru societatea activă.',
    24
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = true;

INSERT INTO public.user_module_permissions (
    user_id,
    module_id,
    can_view,
    can_create,
    can_edit,
    can_delete
)
SELECT
    ump.user_id,
    hr_mod.id,
    ump.can_view,
    ump.can_create,
    ump.can_edit,
    ump.can_delete
FROM public.user_module_permissions ump
JOIN public.modules nom_mod ON nom_mod.id = ump.module_id AND nom_mod.code = 'nomenclatoare'
JOIN public.modules hr_mod ON hr_mod.code = 'hr'
ON CONFLICT (user_id, module_id) DO UPDATE SET
    can_view = EXCLUDED.can_view OR public.user_module_permissions.can_view,
    can_create = EXCLUDED.can_create OR public.user_module_permissions.can_create,
    can_edit = EXCLUDED.can_edit OR public.user_module_permissions.can_edit,
    can_delete = EXCLUDED.can_delete OR public.user_module_permissions.can_delete;
