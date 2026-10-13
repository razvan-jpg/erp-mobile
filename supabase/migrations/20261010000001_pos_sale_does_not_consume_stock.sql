-- Vânzarea nu mai descarcă gestiunea. Apelurile vechi rămân fără efect, ca stocul să nu scadă de două ori.

CREATE OR REPLACE FUNCTION public.pos_consume_stock(p_items jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN;
END;
$$;

GRANT EXECUTE ON FUNCTION public.pos_consume_stock(jsonb) TO authenticated, service_role;
