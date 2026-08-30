-- Redenumire modul supplier_invoices_payments: „Furnizori”

UPDATE public.modules
SET name = 'Furnizori'
WHERE code = 'supplier_invoices_payments';
