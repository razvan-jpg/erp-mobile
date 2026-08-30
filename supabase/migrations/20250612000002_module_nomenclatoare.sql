-- Modul Nomenclatoare (primul modul pe dashboard) + permisiuni oglindite din Produse.

INSERT INTO public.modules (code, name, description, sort_order)
VALUES (
    'nomenclatoare',
    'Nomenclatoare',
    'Catalog articole, produse finite, rețete, materii prime și alte fișe de bază.',
    5
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = true;

UPDATE public.modules SET sort_order = 10 WHERE code = 'supplier_invoices_payments';
UPDATE public.modules SET sort_order = 20 WHERE code = 'inventory';
UPDATE public.modules SET sort_order = 30 WHERE code = 'products';

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
    nom.id,
    ump.can_view,
    ump.can_create,
    ump.can_edit,
    ump.can_delete
FROM public.user_module_permissions ump
JOIN public.modules prod ON prod.id = ump.module_id AND prod.code = 'products'
JOIN public.modules nom ON nom.code = 'nomenclatoare'
ON CONFLICT (user_id, module_id) DO UPDATE SET
    can_view = EXCLUDED.can_view OR public.user_module_permissions.can_view,
    can_create = EXCLUDED.can_create OR public.user_module_permissions.can_create,
    can_edit = EXCLUDED.can_edit OR public.user_module_permissions.can_edit,
    can_delete = EXCLUDED.can_delete OR public.user_module_permissions.can_delete;
