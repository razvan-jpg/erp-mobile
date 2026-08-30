-- Modul ERP: Fișa stoc (articole marcate in_stock_sheet).

INSERT INTO public.modules (code, name, description, sort_order)
VALUES (
    'stock_sheet',
    'Fișa stoc',
    'Fișe de stoc pe articolele marcate „Folosit în Foaie stoc”, cu cantități, cost mediu și valoare.',
    22
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
    stock_mod.id,
    ump.can_view,
    ump.can_create,
    ump.can_edit,
    ump.can_delete
FROM public.user_module_permissions ump
JOIN public.modules inv_mod ON inv_mod.id = ump.module_id AND inv_mod.code = 'inventory'
JOIN public.modules stock_mod ON stock_mod.code = 'stock_sheet'
ON CONFLICT (user_id, module_id) DO UPDATE SET
    can_view = EXCLUDED.can_view OR public.user_module_permissions.can_view,
    can_create = EXCLUDED.can_create OR public.user_module_permissions.can_create,
    can_edit = EXCLUDED.can_edit OR public.user_module_permissions.can_edit,
    can_delete = EXCLUDED.can_delete OR public.user_module_permissions.can_delete;
