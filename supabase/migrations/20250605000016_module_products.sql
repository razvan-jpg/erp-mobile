-- Modul: Produse (coming soon)

INSERT INTO public.modules (code, name, description, sort_order)
VALUES (
    'products',
    'Produse - coming soon...',
    'Catalog, gestionare produse finite, retete, materii prime si marfuri, obiecte de inventar, etc. - disponibil in curand.',
    30
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = true;
