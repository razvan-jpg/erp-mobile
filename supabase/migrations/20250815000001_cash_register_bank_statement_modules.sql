-- Registru de casă și Extras de bancă — module placeholder pe dashboard (implementare ulterioară).

INSERT INTO public.modules (code, name, description, sort_order)
VALUES
    (
        'cash_register',
        'Registru de casă',
        'Încasări și plăți numerar, sold casă, raport zilnic.',
        14
    ),
    (
        'bank_statement',
        'Extras de bancă',
        'Import extras bancar, reconciliere, plăți și încasări.',
        16
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
    cash_mod.id,
    ump.can_view,
    ump.can_create,
    ump.can_edit,
    ump.can_delete
FROM public.user_module_permissions ump
JOIN public.modules client_mod ON client_mod.id = ump.module_id AND client_mod.code = 'client_invoices_payments'
JOIN public.modules cash_mod ON cash_mod.code = 'cash_register'
ON CONFLICT (user_id, module_id) DO UPDATE SET
    can_view = EXCLUDED.can_view OR public.user_module_permissions.can_view,
    can_create = EXCLUDED.can_create OR public.user_module_permissions.can_create,
    can_edit = EXCLUDED.can_edit OR public.user_module_permissions.can_edit,
    can_delete = EXCLUDED.can_delete OR public.user_module_permissions.can_delete;

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
    bank_mod.id,
    ump.can_view,
    ump.can_create,
    ump.can_edit,
    ump.can_delete
FROM public.user_module_permissions ump
JOIN public.modules client_mod ON client_mod.id = ump.module_id AND client_mod.code = 'client_invoices_payments'
JOIN public.modules bank_mod ON bank_mod.code = 'bank_statement'
ON CONFLICT (user_id, module_id) DO UPDATE SET
    can_view = EXCLUDED.can_view OR public.user_module_permissions.can_view,
    can_create = EXCLUDED.can_create OR public.user_module_permissions.can_create,
    can_edit = EXCLUDED.can_edit OR public.user_module_permissions.can_edit,
    can_delete = EXCLUDED.can_delete OR public.user_module_permissions.can_delete;
