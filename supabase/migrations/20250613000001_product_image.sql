-- Imagine articol (URL public Supabase Storage sau sursă externă).

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS imagine_url TEXT;

COMMENT ON COLUMN public.products.imagine_url IS 'URL imagine articol (Storage product-images sau sursă externă).';

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'product-images',
    'product-images',
    true,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE OR REPLACE FUNCTION public.storage_object_company_id(object_name TEXT)
RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(split_part(object_name, '/', 1), '')::UUID;
EXCEPTION
    WHEN invalid_text_representation THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DROP POLICY IF EXISTS "product_images_public_read" ON storage.objects;
DROP POLICY IF EXISTS "product_images_authenticated_read" ON storage.objects;
DROP POLICY IF EXISTS "product_images_insert" ON storage.objects;
DROP POLICY IF EXISTS "product_images_update" ON storage.objects;
DROP POLICY IF EXISTS "product_images_delete" ON storage.objects;

CREATE POLICY "product_images_public_read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'product-images');

CREATE POLICY "product_images_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'product-images'
    AND public.current_user_can_access_selected_company_products_data(
        public.storage_object_company_id(name), 'edit', 'edit'
    )
);

CREATE POLICY "product_images_update"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'product-images'
    AND public.current_user_can_access_selected_company_products_data(
        public.storage_object_company_id(name), 'edit', 'edit'
    )
)
WITH CHECK (
    bucket_id = 'product-images'
    AND public.current_user_can_access_selected_company_products_data(
        public.storage_object_company_id(name), 'edit', 'edit'
    )
);

CREATE POLICY "product_images_delete"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'product-images'
    AND public.current_user_can_access_selected_company_products_data(
        public.storage_object_company_id(name), 'edit', 'edit'
    )
);
