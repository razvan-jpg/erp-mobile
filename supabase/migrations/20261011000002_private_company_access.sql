-- current_user_has_company_access, is_current_user_superadmin și
-- is_current_user_company_admin trăiesc doar în schema private.
-- După mutarea lui current_user_selected_company_id, salvarea e-Factura
-- cădea la următorul apel: "function public.current_user_has_company_access(uuid, text) does not exist".
-- Orice funcție publică care cheamă un helper existent doar în private
-- este rescrisă să folosească schema private.

DO $$
DECLARE
    helper record;
    fn record;
    def text;
    needle text;
    replacement text;
BEGIN
    FOR helper IN
        SELECT proname
        FROM (
            SELECT DISTINCT p.proname
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'private'
              AND p.prokind = 'f'
              AND NOT EXISTS (
                  SELECT 1
                  FROM pg_proc p2
                  JOIN pg_namespace n2 ON n2.oid = p2.pronamespace
                  WHERE n2.nspname = 'public'
                    AND p2.prokind = 'f'
                    AND p2.proname = p.proname
              )
        ) helpers
        ORDER BY length(proname) DESC
    LOOP
        needle := 'public.' || helper.proname || '(';
        replacement := 'private.' || helper.proname || '(';

        FOR fn IN
            SELECT p.oid
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE p.prokind = 'f'
              AND n.nspname = 'public'
              AND strpos(pg_get_functiondef(p.oid), needle) > 0
        LOOP
            def := replace(pg_get_functiondef(fn.oid), needle, replacement);
            EXECUTE def;
        END LOOP;
    END LOOP;
END $$;
