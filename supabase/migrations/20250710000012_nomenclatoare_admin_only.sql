-- Nomenclatoare: acces doar pentru superadmin și admin societate.

CREATE OR REPLACE FUNCTION public.current_user_can_nomenclatoare_module(p_action TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF public.is_current_user_superadmin() THEN
        RETURN true;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.user_profiles
        WHERE id = auth.uid()
          AND is_admin = true
          AND is_superadmin = false
    ) THEN
        RETURN true;
    END IF;

    RETURN false;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

DELETE FROM public.user_module_permissions ump
USING public.modules m, public.user_profiles up
WHERE ump.module_id = m.id
  AND m.code = 'nomenclatoare'
  AND up.id = ump.user_id
  AND NOT (
      up.is_superadmin = true
      OR (up.is_admin = true AND up.is_superadmin = false)
  );
