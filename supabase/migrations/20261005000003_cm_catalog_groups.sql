-- Grupe CM (casă marcat) pentru Catalog: grupe custom, Meniuri, Produse fără grupă.

CREATE TABLE public.cm_product_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'custom'
        CHECK (kind IN ('custom', 'menus', 'ungrouped')),
    is_system BOOLEAN NOT NULL DEFAULT false,
    sort_order INT NOT NULL DEFAULT 100,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, name),
    CHECK (
        (kind = 'custom' AND is_system = false)
        OR (kind IN ('menus', 'ungrouped') AND is_system = true)
    )
);

CREATE UNIQUE INDEX cm_product_groups_system_kind_uidx
    ON public.cm_product_groups (company_id, kind)
    WHERE kind IN ('menus', 'ungrouped');

CREATE INDEX idx_cm_product_groups_company ON public.cm_product_groups(company_id, sort_order, name);

CREATE TRIGGER cm_product_groups_updated_at
    BEFORE UPDATE ON public.cm_product_groups
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Membri: doar grupe custom; max 2 grupe custom per produs (trigger).
CREATE TABLE public.cm_product_group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES public.cm_product_groups(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (group_id, product_id)
);

CREATE INDEX idx_cm_product_group_members_product ON public.cm_product_group_members(product_id);
CREATE INDEX idx_cm_product_group_members_company ON public.cm_product_group_members(company_id);

CREATE OR REPLACE FUNCTION public.cm_product_group_members_validate()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_kind TEXT;
    v_count INT;
BEGIN
    SELECT kind INTO v_kind FROM public.cm_product_groups WHERE id = NEW.group_id;
    IF v_kind IS DISTINCT FROM 'custom' THEN
        RAISE EXCEPTION 'CM_GROUP_MEMBERS_CUSTOM_ONLY';
    END IF;

    SELECT COUNT(*)::INT INTO v_count
    FROM public.cm_product_group_members m
    JOIN public.cm_product_groups g ON g.id = m.group_id
    WHERE m.product_id = NEW.product_id
      AND g.kind = 'custom'
      AND m.id IS DISTINCT FROM NEW.id;

    IF v_count >= 2 THEN
        RAISE EXCEPTION 'CM_GROUP_MEMBER_LIMIT';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER cm_product_group_members_validate_trg
    BEFORE INSERT OR UPDATE ON public.cm_product_group_members
    FOR EACH ROW EXECUTE FUNCTION public.cm_product_group_members_validate();

CREATE OR REPLACE FUNCTION public.cm_product_groups_protect_system()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' AND OLD.is_system THEN
        RAISE EXCEPTION 'CM_GROUP_SYSTEM_DELETE';
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.is_system THEN
        IF NEW.kind IS DISTINCT FROM OLD.kind OR NEW.is_system IS DISTINCT FROM OLD.is_system THEN
            RAISE EXCEPTION 'CM_GROUP_SYSTEM_EDIT';
        END IF;
        -- Allow renaming only for display consistency; keep fixed names for system groups.
        IF OLD.kind = 'menus' THEN
            NEW.name := 'Meniuri';
        ELSIF OLD.kind = 'ungrouped' THEN
            NEW.name := 'Produse fara grupa';
        END IF;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER cm_product_groups_protect_system_trg
    BEFORE UPDATE OR DELETE ON public.cm_product_groups
    FOR EACH ROW EXECUTE FUNCTION public.cm_product_groups_protect_system();

-- Meniuri (în grupa sistem Meniuri)
CREATE TABLE public.cm_menus (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    pret_vanzare NUMERIC(18, 4) NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (company_id, name)
);

CREATE INDEX idx_cm_menus_company ON public.cm_menus(company_id, sort_order, name);

CREATE TRIGGER cm_menus_updated_at
    BEFORE UPDATE ON public.cm_menus
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TABLE public.cm_menu_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    menu_id UUID NOT NULL REFERENCES public.cm_menus(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    cantitate NUMERIC(18, 6) NOT NULL DEFAULT 1 CHECK (cantitate > 0),
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (menu_id, product_id)
);

CREATE INDEX idx_cm_menu_lines_menu ON public.cm_menu_lines(menu_id);
CREATE INDEX idx_cm_menu_lines_product ON public.cm_menu_lines(product_id);

-- Seed grupe sistem pentru societățile existente
INSERT INTO public.cm_product_groups (company_id, name, kind, is_system, sort_order)
SELECT c.id, 'Meniuri', 'menus', true, 9000
FROM public.companies c
WHERE NOT EXISTS (
    SELECT 1 FROM public.cm_product_groups g
    WHERE g.company_id = c.id AND g.kind = 'menus'
);

INSERT INTO public.cm_product_groups (company_id, name, kind, is_system, sort_order)
SELECT c.id, 'Produse fara grupa', 'ungrouped', true, 9100
FROM public.companies c
WHERE NOT EXISTS (
    SELECT 1 FROM public.cm_product_groups g
    WHERE g.company_id = c.id AND g.kind = 'ungrouped'
);

-- La societate nouă, creează grupele sistem
CREATE OR REPLACE FUNCTION public.ensure_cm_system_groups_for_company()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.cm_product_groups (company_id, name, kind, is_system, sort_order)
    SELECT NEW.id, 'Meniuri', 'menus', true, 9000
    WHERE NOT EXISTS (
        SELECT 1 FROM public.cm_product_groups g
        WHERE g.company_id = NEW.id AND g.kind = 'menus'
    );
    INSERT INTO public.cm_product_groups (company_id, name, kind, is_system, sort_order)
    SELECT NEW.id, 'Produse fara grupa', 'ungrouped', true, 9100
    WHERE NOT EXISTS (
        SELECT 1 FROM public.cm_product_groups g
        WHERE g.company_id = NEW.id AND g.kind = 'ungrouped'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS companies_ensure_cm_system_groups ON public.companies;
CREATE TRIGGER companies_ensure_cm_system_groups
    AFTER INSERT ON public.companies
    FOR EACH ROW EXECUTE FUNCTION public.ensure_cm_system_groups_for_company();

ALTER TABLE public.cm_product_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cm_product_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cm_menus ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cm_menu_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cm_product_groups_select" ON public.cm_product_groups FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view'::text, 'view'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'view'::text, 'view'::text));
CREATE POLICY "cm_product_groups_insert" ON public.cm_product_groups FOR INSERT TO authenticated
    WITH CHECK (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create'::text, 'create'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'create'::text, 'create'::text));
CREATE POLICY "cm_product_groups_update" ON public.cm_product_groups FOR UPDATE TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'edit'::text, 'edit'::text))
    WITH CHECK (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'edit'::text, 'edit'::text));
CREATE POLICY "cm_product_groups_delete" ON public.cm_product_groups FOR DELETE TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete'::text, 'delete'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'delete'::text, 'delete'::text));

CREATE POLICY "cm_product_group_members_select" ON public.cm_product_group_members FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view'::text, 'view'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'view'::text, 'view'::text));
CREATE POLICY "cm_product_group_members_insert" ON public.cm_product_group_members FOR INSERT TO authenticated
    WITH CHECK (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create'::text, 'create'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'create'::text, 'create'::text));
CREATE POLICY "cm_product_group_members_update" ON public.cm_product_group_members FOR UPDATE TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'edit'::text, 'edit'::text))
    WITH CHECK (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'edit'::text, 'edit'::text));
CREATE POLICY "cm_product_group_members_delete" ON public.cm_product_group_members FOR DELETE TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete'::text, 'delete'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'delete'::text, 'delete'::text));

CREATE POLICY "cm_menus_select" ON public.cm_menus FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view'::text, 'view'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'view'::text, 'view'::text));
CREATE POLICY "cm_menus_insert" ON public.cm_menus FOR INSERT TO authenticated
    WITH CHECK (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create'::text, 'create'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'create'::text, 'create'::text));
CREATE POLICY "cm_menus_update" ON public.cm_menus FOR UPDATE TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'edit'::text, 'edit'::text))
    WITH CHECK (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'edit'::text, 'edit'::text));
CREATE POLICY "cm_menus_delete" ON public.cm_menus FOR DELETE TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete'::text, 'delete'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'delete'::text, 'delete'::text));

CREATE POLICY "cm_menu_lines_select" ON public.cm_menu_lines FOR SELECT TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view'::text, 'view'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'view'::text, 'view'::text));
CREATE POLICY "cm_menu_lines_insert" ON public.cm_menu_lines FOR INSERT TO authenticated
    WITH CHECK (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create'::text, 'create'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'create'::text, 'create'::text));
CREATE POLICY "cm_menu_lines_update" ON public.cm_menu_lines FOR UPDATE TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'edit'::text, 'edit'::text))
    WITH CHECK (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'edit'::text, 'edit'::text));
CREATE POLICY "cm_menu_lines_delete" ON public.cm_menu_lines FOR DELETE TO authenticated
    USING (private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete'::text, 'delete'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'delete'::text, 'delete'::text));

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cm_product_groups TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cm_product_group_members TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cm_menus TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.cm_menu_lines TO authenticated, service_role;
