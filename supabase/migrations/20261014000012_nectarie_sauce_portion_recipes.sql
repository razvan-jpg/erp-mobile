-- NECTARIE: SOS SAMURAI (84), SOS USTUROI (81), SOS TZATZIKI (1462).
-- Rețeta era scrisă pentru 1 kg. Porția este 0,025 kg, ca la celelalte sosuri.
-- Cantitățile din rețetă se înmulțesc cu 0,025; prețul de producție devine costul porției.
-- Nu se schimbă in_catalog, prețul de vânzare sau facturile.

SELECT set_config('erp.refreshing_recipes', '1', false);

UPDATE public.product_recipe_lines AS prl
SET cantitate = ROUND(prl.cantitate * 0.025, 4)
FROM public.products AS p
WHERE prl.product_id = p.id
  AND p.company_id = '10690ba8-f7cf-47a4-8f93-712d69f5e5a2'
  AND p.tip = 'produs_finit'
  AND p.cod IN ('84', '81', '1462');

SELECT set_config('erp.refreshing_recipes', '0', false);

SELECT public.refresh_recipe_purchase_prices(
  '10690ba8-f7cf-47a4-8f93-712d69f5e5a2',
  NULL
);
