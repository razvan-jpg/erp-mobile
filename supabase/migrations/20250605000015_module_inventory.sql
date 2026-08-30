-- Modul: Stocuri (coming soon)

INSERT INTO public.modules (code, name, description, sort_order)
VALUES (
    'inventory',
    'Stocuri - coming soon...',
    'Gestionare stocuri și inventar — disponibil în curând.',
    20
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order,
    is_active = true;
