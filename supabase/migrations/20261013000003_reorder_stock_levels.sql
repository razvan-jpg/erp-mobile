-- Stoc minim / optim pe categorii, pentru necesarul de comandă.
-- Birotica rămâne cu 0 ca să nu intre automat în listă.

UPDATE public.products
SET cantitate_optima = 15
WHERE tip = 'materiale_consumabile';

UPDATE public.products
SET cantitate_minima = 1,
    cantitate_optima = 3
WHERE tip = 'materiale_curatenie';

UPDATE public.products
SET cantitate_minima = 0,
    cantitate_optima = 0
WHERE tip = 'birotica';
