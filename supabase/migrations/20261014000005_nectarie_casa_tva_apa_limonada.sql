-- NECTARIE, casa de marcat: apa 0,5 L cu cota B (11%), limonadele cu cota A (21%).

UPDATE public.products
SET cota_tva = 11,
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND id IN (
      '8f90bbeb-d822-4aa7-9e23-0fb7af54c106',
      'd399f5bc-3265-4da1-8350-017bbfe2a786'
  )
  AND cod IN ('1469', '1470')
  AND cota_tva IS DISTINCT FROM 11;

UPDATE public.products
SET cota_tva = 21,
    updated_at = now()
WHERE company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND id IN (
      '1dbea2f6-749a-410e-bcaf-4f36ef0115e2',
      'e305ee76-9bca-4c3a-a739-48a79c230bfe',
      '493c7291-ea10-44c3-92ac-2444f1f13274',
      'ba5c8faa-0680-4b84-9a20-ab9ce1d94fc6'
  )
  AND cod IN ('1122', '1270', '1269', '1128')
  AND cota_tva IS DISTINCT FROM 21;
