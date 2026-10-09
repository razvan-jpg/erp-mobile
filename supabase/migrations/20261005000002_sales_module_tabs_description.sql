-- Actualizează descrierea modulului Vânzări (tab-uri BINA BF + vânzare casă marcat).

UPDATE public.modules
SET
    description = 'Preluare BF din BINA și vânzare pe casă de marcat.',
    sort_order = 13,
    is_active = true
WHERE code = 'sales';
