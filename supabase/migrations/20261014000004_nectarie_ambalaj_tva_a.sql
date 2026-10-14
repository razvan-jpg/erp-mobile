-- NECTARIE: Taxa ambalaj (1121) și Taxa ambalaj mică (1180) se trimit pe bon cu cota A (21%), nu B (11%).

UPDATE public.products
SET cota_tva = 21,
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND id IN (
      'fd568111-ab87-422b-ac27-4dd727fb3fd0',
      '69db7a42-13bf-445e-b4dd-131b245728b9'
  )
  AND cod IN ('1121', '1180')
  AND tip = 'ambalaj'
  AND cota_tva IS DISTINCT FROM 21;
