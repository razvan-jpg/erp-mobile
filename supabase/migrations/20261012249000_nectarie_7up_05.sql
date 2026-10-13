-- NECTARIE: master 7UP LEMON LIME 0.5 L (cod 1477).
-- Nu modificam in_catalog (ramane in catalog).

UPDATE public.products
SET denumire = '7UP LEMON LIME 0.5 L',
    tip = 'marfa',
    is_active = true,
    updated_at = now()
WHERE id = 'e27c9ce0-f592-4ecd-95d1-5db65255627e'
  AND company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND cod = '1477';
