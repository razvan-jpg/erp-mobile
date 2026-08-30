-- Administratorii de societate primesc și ei emailul de activare (doar superadminul e exclus)

CREATE OR REPLACE FUNCTION public.notify_welcome_email()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  fn_url text := 'https://uygkcpllczvpdtinjjih.supabase.co/functions/v1/send-welcome-email';
  fn_secret text := 'erp-welcome-uygkcpllczvpdtinjjih-v1';
BEGIN
  IF NEW.email_confirmed_at IS NOT NULL
     AND (OLD.email_confirmed_at IS NULL OR OLD.email_confirmed_at IS DISTINCT FROM NEW.email_confirmed_at)
     AND COALESCE((NEW.raw_user_meta_data->>'is_superadmin')::boolean, false) = false
     AND COALESCE((NEW.raw_user_meta_data->>'welcome_email_sent')::boolean, false) = false THEN
    PERFORM net.http_post(
      url := fn_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-trigger-secret', fn_secret
      ),
      body := jsonb_build_object('user_id', NEW.id::text)
    );
  END IF;
  RETURN NEW;
END;
$$;
