-- Bucket public pentru pagina statică de confirmare email (HTML nu poate fi servit din Edge Functions)

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'erp-static',
    'erp-static',
    true,
    1048576,
    ARRAY['text/html']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    allowed_mime_types = ARRAY['text/html'];

DROP POLICY IF EXISTS "Public read erp-static" ON storage.objects;
DROP POLICY IF EXISTS "Service role upload erp-static" ON storage.objects;
DROP POLICY IF EXISTS "Service role update erp-static" ON storage.objects;
DROP POLICY IF EXISTS "Service role delete erp-static" ON storage.objects;

CREATE POLICY "Public read erp-static"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'erp-static');

CREATE POLICY "Service role upload erp-static"
ON storage.objects FOR INSERT
TO service_role
WITH CHECK (bucket_id = 'erp-static');

CREATE POLICY "Service role update erp-static"
ON storage.objects FOR UPDATE
TO service_role
USING (bucket_id = 'erp-static');

CREATE POLICY "Service role delete erp-static"
ON storage.objects FOR DELETE
TO service_role
USING (bucket_id = 'erp-static');
