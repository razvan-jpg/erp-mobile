import { handleCors } from "../_shared/cors.ts";
import { getServiceClient } from "../_shared/admin.ts";
import { authorizeUrl, htmlPage, loadOauthApp } from "../_shared/anaf-oauth.ts";

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;
  if (req.method !== "GET") {
    return htmlPage("Autorizare SPV", "Deschideți linkul primit pe email.");
  }

  const token = new URL(req.url).searchParams.get("token") ?? "";
  if (!token) {
    return htmlPage("Autorizare SPV", "Linkul nu este complet. Deschideți invitația primită pe email.");
  }

  const service = getServiceClient();
  const { data: invite } = await service
    .from("anaf_oauth_invites")
    .select("token, company_id, invited_by, expires_at")
    .eq("token", token)
    .maybeSingle();

  if (!invite || new Date(invite.expires_at).getTime() < Date.now()) {
    return htmlPage(
      "Invitația a expirat",
      "Linkul este valabil 7 zile. Cereți o invitație nouă din ERP Mobile.",
    );
  }

  const app = await loadOauthApp();
  if (!app) {
    return htmlPage(
      "Aplicația nu este înrolată",
      "Lipsește înregistrarea ERP Mobile la ANAF. Superadminul o salvează o singură dată, în Setări.",
    );
  }

  const state = crypto.randomUUID();
  const { error } = await service.from("anaf_oauth_states").insert({
    state,
    company_id: invite.company_id,
    user_id: invite.invited_by,
    expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
  });
  if (error) {
    return htmlPage("Autorizarea nu a pornit", "Reîncercați linkul din email. Dacă ANAF arată session finished, reporniți browserul.");
  }

  return Response.redirect(authorizeUrl(app, state), 302);
});
