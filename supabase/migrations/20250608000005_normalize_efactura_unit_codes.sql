-- Normalizare unități de măsură e-Factura (UN/ECE) pe datele deja importate.

CREATE OR REPLACE FUNCTION public.normalize_efactura_unit_code(p_code TEXT)
RETURNS TEXT AS $$
DECLARE
    v_trimmed TEXT := btrim(COALESCE(p_code, ''));
    v_key TEXT := lower(v_trimmed);
BEGIN
    IF v_trimmed = '' THEN
        RETURN 'Buc.';
    END IF;

    RETURN CASE v_key
        WHEN 'h87' THEN 'Buc.'
        WHEN 'buc' THEN 'Buc.'
        WHEN 'ltr' THEN 'litru'
        WHEN 'set' THEN 'set'
        WHEN 'kgm' THEN 'Kg.'
        WHEN 'mtq' THEN 'm3'
        WHEN 'xpx' THEN 'palet'
        WHEN 'xbx' THEN 'cutie'
        ELSE lower(v_trimmed)
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

UPDATE public.products
SET unitate_masura = public.normalize_efactura_unit_code(unitate_masura)
WHERE unitate_masura IS DISTINCT FROM public.normalize_efactura_unit_code(unitate_masura);

UPDATE public.supplier_invoice_lines
SET unitate_masura = public.normalize_efactura_unit_code(unitate_masura)
WHERE unitate_masura IS DISTINCT FROM public.normalize_efactura_unit_code(unitate_masura);

UPDATE public.stock_movements
SET unitate_masura = public.normalize_efactura_unit_code(unitate_masura)
WHERE unitate_masura IS DISTINCT FROM public.normalize_efactura_unit_code(unitate_masura);
