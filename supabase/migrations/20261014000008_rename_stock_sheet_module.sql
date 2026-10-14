-- Tile-ul de pe Acasă: Fișa stoc devine Foaie stoc.

UPDATE public.modules
SET
    name = 'Foaie stoc',
    description = 'Foi de stoc pe articolele marcate „Folosit în Foaie stoc”, cu cantități, cost mediu și valoare.'
WHERE code = 'stock_sheet';
