/** HTML nu poate fi randat de pe domeniul Supabase (Edge Functions / Storage → text/plain). */
export const DEFAULT_CONFIRM_PAGE_URL = "https://rincon.ro/email-confirmat.html";

export function getEmailConfirmRedirectUrl(): string {
  const custom = Deno.env.get("EMAIL_CONFIRM_REDIRECT_URL")?.trim();
  if (custom && !custom.includes("/functions/v1/email-confirmed")
    && !custom.includes("/storage/v1/object/public/")) {
    return custom;
  }
  return DEFAULT_CONFIRM_PAGE_URL;
}
