-- Row Level Security policies

ALTER TABLE public.modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_module_permissions ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.is_current_user_admin()
RETURNS BOOLEAN AS $$
    SELECT COALESCE(
        (SELECT is_admin FROM public.user_profiles WHERE id = auth.uid()),
        false
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public;

-- modules: everyone authenticated can read active modules; admin manages all
CREATE POLICY "modules_select_authenticated"
    ON public.modules FOR SELECT
    TO authenticated
    USING (is_active = true OR public.is_current_user_admin());

CREATE POLICY "modules_admin_all"
    ON public.modules FOR ALL
    TO authenticated
    USING (public.is_current_user_admin())
    WITH CHECK (public.is_current_user_admin());

-- user_profiles: own profile or admin
CREATE POLICY "profiles_select_own_or_admin"
    ON public.user_profiles FOR SELECT
    TO authenticated
    USING (id = auth.uid() OR public.is_current_user_admin());

CREATE POLICY "profiles_update_own_or_admin"
    ON public.user_profiles FOR UPDATE
    TO authenticated
    USING (id = auth.uid() OR public.is_current_user_admin())
    WITH CHECK (id = auth.uid() OR public.is_current_user_admin());

CREATE POLICY "profiles_delete_admin"
    ON public.user_profiles FOR DELETE
    TO authenticated
    USING (public.is_current_user_admin());

CREATE POLICY "profiles_insert_admin"
    ON public.user_profiles FOR INSERT
    TO authenticated
    WITH CHECK (public.is_current_user_admin());

-- user_module_permissions: own permissions or admin
CREATE POLICY "permissions_select_own_or_admin"
    ON public.user_module_permissions FOR SELECT
    TO authenticated
    USING (user_id = auth.uid() OR public.is_current_user_admin());

CREATE POLICY "permissions_admin_manage"
    ON public.user_module_permissions FOR ALL
    TO authenticated
    USING (public.is_current_user_admin())
    WITH CHECK (public.is_current_user_admin());
