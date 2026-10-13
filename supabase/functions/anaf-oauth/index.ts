import { handleCors } from "../_shared/cors.ts";
import {
  getCallerWritableCompanyIds,
  getServiceClient,
  jsonResponse,
  requireAuthenticatedUser,
  requireSuperAdmin,
} from "../_shared/admin.ts";
import { getEmailFromAddress, sendResendEmail } from "../_shared/resend.ts";
import {
  bucharestDay,
  inviteExpiry,
  inviteUrl,
  loadOauthApp,
  redirectUri,
  refreshAccessToken,
  revokeRefreshToken,
} from "../_shared/anaf-oauth.ts";

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;
  if (req.method !== "POST") return jsonResponse({ error: "Metodă nepermisă" }, 405);

  try {
    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? "");
    if (action === "status") return await status(req);
    if (action === "save") return await save(req, body);
    if (action === "invite") return await invite(req, body);
    if (action === "refresh") return await refresh(req, body);
    if (action === "revoke") return await revoke(req, body);
    return jsonResponse({ error: "Acțiune necunoscută" }, 400);
  } catch (err) {
    if (err instanceof Response) return err;
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});

async function status(req: Request): Promise<Response> {
  const { profile } = await requireAuthenticatedUser(req);
  const app = await loadOauthApp();
  const payload: Record<string, unknown> = {
    configured: app !== null,
    redirect_uri: redirectUri(),
  };
  if (profile.is_superadmin && app) payload.client_id = app.client_id;
  return jsonResponse(payload);
}

async function save(req: Request, body: Record<string, unknown>): Promise<Response> {
  const { serviceClient } = await requireSuperAdmin(req);
  const clientId = String(body.client_id ?? "").trim();
  let clientSecret = String(body.client_secret ?? "").trim();
  if (!clientId) return jsonResponse({ error: "Completați Client ID." }, 400);

  if (!clientSecret) {
    const existing = await loadOauthApp();
    clientSecret = existing?.client_secret ?? "";
  }
  if (!clientSecret) return jsonResponse({ error: "Completați Client Secret." }, 400);

  const { error } = await serviceClient.from("anaf_oauth_app").upsert({
    id: 1,
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: redirectUri(),
    updated_at: new Date().toISOString(),
  });
  if (error) return jsonResponse({ error: error.message }, 400);
  return jsonResponse({ saved: true, redirect_uri: redirectUri() });
}

async function invite(req: Request, body: Record<string, unknown>): Promise<Response> {
  const { profile, serviceClient } = await requireAuthenticatedUser(req);
  const companyId = String(body.company_id ?? "").trim();
  const email = String(body.accountant_email ?? "").trim();
  if (!companyId) return jsonResponse({ error: "Selectați o societate." }, 400);
  if (!isEmail(email)) return jsonResponse({ error: "Completați un email valid pentru contabil." }, 400);

  const access = await assertCompanyWrite(serviceClient, profile, companyId);
  if (access) return access;
  const missing = await requireApp();
  if (missing) return missing;

  const { data: company, error: companyError } = await serviceClient
    .from("companies")
    .select("denumire, cui")
    .eq("id", companyId)
    .maybeSingle();
  if (companyError || !company) return jsonResponse({ error: "Societatea nu a fost găsită." }, 404);

  const token = crypto.randomUUID();
  const sentAt = new Date();
  const expiresAt = inviteExpiry(sentAt);
  const { error } = await serviceClient.from("anaf_oauth_invites").insert({
    token,
    company_id: companyId,
    email,
    invited_by: profile.id,
    expires_at: expiresAt.toISOString(),
    sent_at: sentAt.toISOString(),
  });
  if (error) return jsonResponse({ error: error.message }, 400);

  const name = String(company.denumire ?? "").trim() || "—";
  const cui = String(company.cui ?? "").trim() || "—";
  const until = expiresAt.toLocaleString("ro-RO", { timeZone: "Europe/Bucharest" });
  const mailed = await sendResendEmail({
    to: [email],
    subject: `Autorizare SPV e-Factura — ${name}`,
    text: [
      "Bună ziua,",
      "",
      `Ați primit o invitație să autorizați societatea ${name} (CUI ${cui}) în SPV, pentru e-Factura, din ERP Mobile.`,
      "",
      "Deschideți linkul de pe calculatorul pe care este instalată semnătura electronică:",
      inviteUrl(token),
      "",
      `Linkul este valabil 7 zile, până la ${until}.`,
      "",
      "Dacă ANAF arată „session finished” / hangup, reporniți browserul și deschideți din nou același link.",
    ].join("\n"),
  });
  if (!mailed.ok) {
    await serviceClient.from("anaf_oauth_invites").delete().eq("token", token);
    return jsonResponse({ error: mailed.error ?? "Emailul nu a putut fi trimis." }, 400);
  }

  const { data: existing } = await serviceClient
    .from("company_efactura_settings")
    .select("auth_status, auth_requested_at, auth_authorized_at, auth_valid_until")
    .eq("company_id", companyId)
    .maybeSingle();
  await serviceClient.from("company_efactura_settings").upsert({
    company_id: companyId,
    accountant_email: email,
    auth_status: existing?.auth_status === "authorized" ? "authorized" : "requested",
    auth_requested_at: existing?.auth_requested_at ?? sentAt.toISOString(),
    auth_authorized_at: existing?.auth_authorized_at ?? null,
    auth_valid_until: existing?.auth_valid_until ?? null,
    auth_invite_sent_at: sentAt.toISOString(),
    auth_invite_expires_at: expiresAt.toISOString(),
  });

  return jsonResponse({
    sent: true,
    sent_at: sentAt.toISOString(),
    expires_at: expiresAt.toISOString(),
    from: getEmailFromAddress(),
  });
}

async function refresh(req: Request, body: Record<string, unknown>): Promise<Response> {
  const { profile, serviceClient } = await requireAuthenticatedUser(req);
  const companyId = String(body.company_id ?? "").trim();
  const access = await assertCompanyWrite(serviceClient, profile, companyId);
  if (access) return access;
  const app = await loadOauthApp();
  if (!app) return jsonResponse({ error: "Aplicația nu este înrolată la ANAF." }, 400);

  const { data: tokens } = await serviceClient
    .from("company_anaf_tokens")
    .select("refresh_token")
    .eq("company_id", companyId)
    .maybeSingle();
  if (!tokens?.refresh_token) {
    return jsonResponse({ error: "Nu există o conectare SPV de prelungit. Invitați contabilul pe email." }, 400);
  }

  try {
    const next = await refreshAccessToken(app, tokens.refresh_token);
    const now = new Date().toISOString();
    const { error } = await serviceClient.from("company_anaf_tokens").upsert({
      company_id: companyId,
      access_token: next.accessToken,
      refresh_token: next.refreshToken,
      access_expires_at: next.accessExpiresAt.toISOString(),
      refresh_expires_at: next.refreshExpiresAt.toISOString(),
      authorized_at: now,
    });
    if (error) return jsonResponse({ error: error.message }, 400);
    await serviceClient.from("company_efactura_settings").update({
      auth_status: "authorized",
      auth_authorized_at: now,
      auth_valid_until: bucharestDay(next.accessExpiresAt),
    }).eq("company_id", companyId);
    return jsonResponse({ refreshed: true, valid_until: bucharestDay(next.accessExpiresAt) });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Prelungirea nu a reușit.";
    return jsonResponse({ error: `${message} Trimiteți o invitație nouă contabilului.` }, 400);
  }
}

async function revoke(req: Request, body: Record<string, unknown>): Promise<Response> {
  const { profile, serviceClient } = await requireAuthenticatedUser(req);
  const companyId = String(body.company_id ?? "").trim();
  const access = await assertCompanyWrite(serviceClient, profile, companyId);
  if (access) return access;

  const app = await loadOauthApp();
  const { data: tokens } = await serviceClient
    .from("company_anaf_tokens")
    .select("refresh_token")
    .eq("company_id", companyId)
    .maybeSingle();
  if (app && tokens?.refresh_token) {
    await revokeRefreshToken(app, tokens.refresh_token);
  }
  await serviceClient.from("company_anaf_tokens").delete().eq("company_id", companyId);
  await serviceClient.from("company_efactura_settings").update({
    auth_status: "none",
    auth_authorized_at: null,
    auth_valid_until: null,
  }).eq("company_id", companyId);
  return jsonResponse({ revoked: true });
}

async function assertCompanyWrite(
  serviceClient: ReturnType<typeof getServiceClient>,
  profile: { id: string; is_superadmin: boolean },
  companyId: string,
): Promise<Response | null> {
  if (!companyId) return jsonResponse({ error: "Selectați o societate." }, 400);
  const writable = await getCallerWritableCompanyIds(serviceClient, profile);
  if (writable !== null && !writable.includes(companyId)) {
    return jsonResponse({ error: "Nu aveți drept de modificare pe această societate." }, 403);
  }
  return null;
}

async function requireApp(): Promise<Response | null> {
  const app = await loadOauthApp();
  if (app) return null;
  return jsonResponse({
    error: "Aplicația nu este încă înrolată la ANAF. Superadminul salvează Client ID și Client Secret, o singură dată. Semnătura nu se instalează pe calculatoare.",
  }, 400);
}

function isEmail(value: string): boolean {
  if (value.length < 6 || value.length > 200 || value.includes(" ")) return false;
  const at = value.indexOf("@");
  return at > 0 && at < value.length - 1 && value.indexOf("@", at + 1) === -1 && value.includes(".");
}
