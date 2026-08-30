-- Modul: Gestionare facturi furnizori / Plăți

INSERT INTO public.modules (code, name, description, sort_order)
VALUES (
    'supplier_invoices_payments',
    'Gestionare facturi furnizori / Plăți',
    'Înregistrare și urmărire facturi furnizori, programare și efectuare plăți.',
    10
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = true;
