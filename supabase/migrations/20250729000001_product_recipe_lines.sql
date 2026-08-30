-- Rețete produse: linii materie primă + mapare Bina Smart Business

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS bina_item_id BIGINT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_products_company_bina_item_id
    ON public.products(company_id, bina_item_id)
    WHERE bina_item_id IS NOT NULL;

COMMENT ON COLUMN public.products.bina_item_id IS 'ID articol Bina Smart Business (import rețete).';

CREATE TABLE public.product_recipe_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    ingredient_product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    numar_linie INT NOT NULL CHECK (numar_linie > 0),
    cantitate NUMERIC(14, 4) NOT NULL CHECK (cantitate > 0),
    unitate_masura TEXT NOT NULL,
    pret_achizitie NUMERIC(14, 4),
    pret_achizitie_sursa TEXT NOT NULL DEFAULT 'local'
        CHECK (pret_achizitie_sursa IN ('local', 'bina')),
    bina_component_item_id BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (product_id, ingredient_product_id)
);

CREATE INDEX idx_product_recipe_lines_product
    ON public.product_recipe_lines(product_id);
CREATE INDEX idx_product_recipe_lines_company
    ON public.product_recipe_lines(company_id);
CREATE INDEX idx_product_recipe_lines_ingredient
    ON public.product_recipe_lines(ingredient_product_id);

COMMENT ON TABLE public.product_recipe_lines IS 'Linii rețetă: materii prime și cantități pentru produse finite.';
COMMENT ON COLUMN public.product_recipe_lines.pret_achizitie IS 'Preț achiziție unitar folosit la calcul cost rețetă.';
COMMENT ON COLUMN public.product_recipe_lines.pret_achizitie_sursa IS 'local = din facturi/stoc ERP; bina = fallback import Bina.';

ALTER TABLE public.product_recipe_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "product_recipe_lines_select" ON public.product_recipe_lines FOR SELECT TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'view', 'view'));

CREATE POLICY "product_recipe_lines_insert" ON public.product_recipe_lines FOR INSERT TO authenticated
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'create', 'create'));

CREATE POLICY "product_recipe_lines_update" ON public.product_recipe_lines FOR UPDATE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'))
    WITH CHECK (public.current_user_can_access_selected_company_data(company_id, 'edit', 'edit'));

CREATE POLICY "product_recipe_lines_delete" ON public.product_recipe_lines FOR DELETE TO authenticated
    USING (public.current_user_can_access_selected_company_data(company_id, 'delete', 'delete'));
