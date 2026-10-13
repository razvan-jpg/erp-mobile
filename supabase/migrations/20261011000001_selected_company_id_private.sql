-- public.current_user_selected_company_id() a fost mutată în schema private.
-- Funcțiile de acces încă o apelau pe cea publică, așa că salvarea setărilor
-- e-Factura (și registrul de casă, HR, stocul inițial) cădea cu
-- "function public.current_user_selected_company_id() does not exist".

DO $$
DECLARE
    fn record;
    def text;
BEGIN
    FOR fn IN
        SELECT p.oid
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE p.prokind = 'f'
          AND n.nspname = 'public'
          AND pg_get_functiondef(p.oid) ILIKE '%public.current_user_selected_company_id%'
    LOOP
        def := replace(
            pg_get_functiondef(fn.oid),
            'public.current_user_selected_company_id()',
            'private.current_user_selected_company_id()'
        );
        EXECUTE def;
    END LOOP;
END $$;
