import { handleCors } from "../_shared/cors.ts";
import { getServiceClient } from "../_shared/admin.ts";
import {
  bucharestDay,
  exchangeAuthorizationCode,
  htmlPage,
  loadOauthApp,
} from "../_shared/anaf-oauth.ts";

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;
  if (req.method !== "GET") {
    return htmlPage("Autorizare SPV", "Deschideți autorizarea din ERP Mobile.");
  }

  const url = new URL(req.url);
  const oauthError = url.searchParams.get("error_description") || url.searchParams.get("error");
  if (oauthError) {
    return htmlPage("Autorizarea nu a reușit", oauthError);
  }

  const code = url.searchParams.get("code") ?? "";
  const state = url.searchParams.get("state") ?? "";
  if (!code || !state) {
    return htmlPage(
      "Autorizare SPV",
      "Linkul nu conține codul ANAF. Reveniți în ERP Mobile și apăsați din nou Autorizare SPV.",
    );
  }

  const service = getServiceClient();
  const { data: pending } = await service
    .from("anaf_oauth_states")
    .select("state, company_id, expires_at")
    .eq("state", state)
    .maybeSingle();
  await service.from("anaf_oauth_states").delete().eq("state", state);

  if (!pending || new Date(pending.expires_at).getTime() < Date.now()) {
    return htmlPage(
      "Autorizarea a expirat",
      "Reveniți în ERP Mobile și apăsați din nou Autorizare SPV.",
    );
  }

  const app = await loadOauthApp();
  if (!app) {
    return htmlPage(
      "Aplicația nu este înrolată",
      "Lipsește Client ID-ul înregistrat la ANAF. Superadminul îl salvează în Setări → e-Factura (SPV).",
    );
  }

  try {
    const tokens = await exchangeAuthorizationCode(app, code);
    const companyId = pending.company_id as string;
    const { error: tokenError } = await service.from("company_anaf_tokens").upsert({
      company_id: companyId,
      access_token: tokens.accessToken,
      refresh_token: tokens.refreshToken,
      access_expires_at: tokens.accessExpiresAt.toISOString(),
      refresh_expires_at: tokens.refreshExpiresAt.toISOString(),
      authorized_at: new Date().toISOString(),
    });
    if (tokenError) throw new Error(tokenError.message);

    const { data: existing } = await service
      .from("company_efactura_settings")
      .select("accountant_email, auth_requested_at")
      .eq("company_id", companyId)
      .maybeSingle();
    const now = new Date().toISOString();
    const { error: settingsError } = await service.from("company_efactura_settings").upsert({
      company_id: companyId,
      accountant_email: existing?.accountant_email ?? null,
      auth_status: "authorized",
      auth_requested_at: existing?.auth_requested_at ?? now,
      auth_authorized_at: now,
      auth_valid_until: bucharestDay(tokens.accessExpiresAt),
    });
    if (settingsError) throw new Error(settingsError.message);

    return htmlPage(
      "Autorizare SPV reușită",
      `Societatea este autorizată în SPV până la ${bucharestDay(tokens.accessExpiresAt)}. Data este citită din SPV. Puteți închide această fereastră și reveni în ERP Mobile.`,
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : "ANAF nu a eliberat tokenul.";
    return htmlPage(
      "Autorizarea nu a reușit",
      `${message} Verificați Client ID, Client Secret și că Callback URL din portalul ANAF este identic cu cel din ERP Mobile.`,
    );
  }
});
