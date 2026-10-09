-- PDF-urile de bon și factură fiscală, ca să le deschidă codul QR.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'pos-documents',
    'pos-documents',
    true,
    10485760,
    ARRAY['application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "pos_documents_public_read" ON storage.objects;
DROP POLICY IF EXISTS "pos_documents_insert" ON storage.objects;

CREATE POLICY "pos_documents_public_read"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'pos-documents');

CREATE POLICY "pos_documents_insert"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'pos-documents'
    AND public.storage_object_company_id(name) = private.current_user_selected_company_id()
    AND public.pos_operator_can_record()
);
