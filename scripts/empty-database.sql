-- Golește toate datele ERP Mobile (păstrează schema, funcțiile și migrările)

BEGIN;

TRUNCATE TABLE
    public.supplier_payments,
    public.supplier_invoices,
    public.suppliers,
    public.user_company_permissions,
    public.companies,
    public.user_module_permissions,
    public.user_profiles,
    public.modules
RESTART IDENTITY CASCADE;

DELETE FROM auth.sessions;
DELETE FROM auth.refresh_tokens;
DELETE FROM auth.identities;
DELETE FROM auth.users;

INSERT INTO public.modules (code, name, description, sort_order)
VALUES (
    'nomenclatoare',
    'Nomenclatoare',
    'Catalog articole, produse finite, rețete, materii prime și alte fișe de bază.',
    5
),
(
    'supplier_invoices_payments',
    'Furnizori',
    'Înregistrare și urmărire facturi furnizori, programare și efectuare plăți.',
    10
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = true;

COMMIT;
