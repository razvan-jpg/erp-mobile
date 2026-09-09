SELECT c.id, c.denumire, c.cui
FROM public.companies c
WHERE c.id = '7fe42fd8-a72c-4135-9fba-586ca122ad56'
   OR c.denumire ILIKE '%genic%';
