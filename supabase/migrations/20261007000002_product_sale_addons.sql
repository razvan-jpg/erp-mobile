-- Produse adiționale la vânzare (ex. Garantie SGR pe băuturi):
-- la vânzarea produsului părinte apar pe bon linii separate, cu prețul și cota TVA ale adiționalului.

CREATE TABLE IF NOT EXISTS public.product_sale_addons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    addon_product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    cantitate NUMERIC(14, 4) NOT NULL DEFAULT 1 CHECK (cantitate > 0),
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (product_id, addon_product_id),
    CHECK (product_id <> addon_product_id)
);

CREATE INDEX IF NOT EXISTS idx_product_sale_addons_product
    ON public.product_sale_addons(product_id, sort_order);

CREATE INDEX IF NOT EXISTS idx_product_sale_addons_company
    ON public.product_sale_addons(company_id);

CREATE INDEX IF NOT EXISTS idx_product_sale_addons_addon
    ON public.product_sale_addons(addon_product_id);

COMMENT ON TABLE public.product_sale_addons IS
    'Produse adiționale auto-adăugate pe bon la vânzarea produsului părinte (ex. SGR), cu preț/TVA din fișa adiționalului.';
COMMENT ON COLUMN public.product_sale_addons.cantitate IS
    'Cantitate adițional per 1 unitate produs părinte (de obicei 1 pentru SGR).';

DROP TRIGGER IF EXISTS product_sale_addons_updated_at ON public.product_sale_addons;
CREATE TRIGGER product_sale_addons_updated_at
    BEFORE UPDATE ON public.product_sale_addons
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.product_sale_addons_validate()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_company UUID;
    v_addon_company UUID;
BEGIN
    SELECT company_id INTO v_company FROM public.products WHERE id = NEW.product_id;
    SELECT company_id INTO v_addon_company FROM public.products WHERE id = NEW.addon_product_id;

    IF v_company IS NULL OR v_addon_company IS NULL THEN
        RAISE EXCEPTION 'PRODUCT_SALE_ADDON_MISSING_PRODUCT';
    END IF;
    IF v_company <> NEW.company_id OR v_addon_company <> NEW.company_id THEN
        RAISE EXCEPTION 'PRODUCT_SALE_ADDON_COMPANY_MISMATCH';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS product_sale_addons_validate_trg ON public.product_sale_addons;
CREATE TRIGGER product_sale_addons_validate_trg
    BEFORE INSERT OR UPDATE ON public.product_sale_addons
    FOR EACH ROW EXECUTE FUNCTION public.product_sale_addons_validate();

ALTER TABLE public.product_sale_addons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "product_sale_addons_select" ON public.product_sale_addons;
DROP POLICY IF EXISTS "product_sale_addons_insert" ON public.product_sale_addons;
DROP POLICY IF EXISTS "product_sale_addons_update" ON public.product_sale_addons;
DROP POLICY IF EXISTS "product_sale_addons_delete" ON public.product_sale_addons;

CREATE POLICY "product_sale_addons_select" ON public.product_sale_addons FOR SELECT TO authenticated
    USING (
        private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'view'::text, 'view'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'view'::text, 'view'::text)
    );

CREATE POLICY "product_sale_addons_insert" ON public.product_sale_addons FOR INSERT TO authenticated
    WITH CHECK (
        private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'create'::text, 'create'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'create'::text, 'create'::text)
    );

CREATE POLICY "product_sale_addons_update" ON public.product_sale_addons FOR UPDATE TO authenticated
    USING (
        private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'edit'::text, 'edit'::text)
    )
    WITH CHECK (
        private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'edit'::text, 'edit'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'edit'::text, 'edit'::text)
    );

CREATE POLICY "product_sale_addons_delete" ON public.product_sale_addons FOR DELETE TO authenticated
    USING (
        private.current_user_can_access_selected_company_nomenclatoare_data(company_id, 'delete'::text, 'delete'::text)
        OR private.current_user_can_access_selected_company_products_data(company_id, 'delete'::text, 'delete'::text)
    );

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.product_sale_addons TO authenticated, service_role;
