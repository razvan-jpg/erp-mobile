import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { getEmailConfirmRedirectUrl } from "./redirect-url.ts";

export async function generateSignupConfirmationLink(
  serviceClient: SupabaseClient,
  email: string,
  password: string,
): Promise<{ link: string | null; error: string | null }> {
  const redirectTo = getEmailConfirmRedirectUrl();

  const { data, error } = await serviceClient.auth.admin.generateLink({
    type: "signup",
    email,
    password,
    options: redirectTo ? { redirectTo } : undefined,
  });

  if (error) {
    return { link: null, error: error.message };
  }

  const link = data?.properties?.action_link ?? null;
  if (!link) {
    return { link: null, error: "Linkul de confirmare nu a putut fi generat." };
  }

  return { link, error: null };
}

export async function generateMagicLinkConfirmation(
  serviceClient: SupabaseClient,
  email: string,
): Promise<{ link: string | null; error: string | null }> {
  const redirectTo = getEmailConfirmRedirectUrl();

  const { data, error } = await serviceClient.auth.admin.generateLink({
    type: "magiclink",
    email,
    options: redirectTo ? { redirectTo } : undefined,
  });

  if (error) {
    return { link: null, error: error.message };
  }

  const link = data?.properties?.action_link ?? null;
  if (!link) {
    return { link: null, error: "Linkul de confirmare nu a putut fi generat." };
  }

  return { link, error: null };
}
