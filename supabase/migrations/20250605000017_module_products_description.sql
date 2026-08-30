-- Actualizare descriere modul Produse

UPDATE public.modules
SET description = 'Catalog, gestionare produse finite, retete, materii prime si marfuri, obiecte de inventar, etc. - disponibil in curand.'
WHERE code = 'products';
