import { handleCors } from "../_shared/cors.ts";
import {
  getCallerWritableCompanyIds,
  jsonResponse,
  requireAuthenticatedUser,
} from "../_shared/admin.ts";
import { sendResendEmail } from "../_shared/resend.ts";

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  try {
    const { profile, serviceClient } = await requireAuthenticatedUser(req);
    const body = await req.json().catch(() => ({}));
    const companyId = String(body.company_id ?? "").trim();
    const email = String(body.accountant_email ?? "").trim();

    if (!isEmail(email)) {
      return jsonResponse({ error: "Completați un email valid pentru contabil." }, 400);
    }

    const writable = await getCallerWritableCompanyIds(serviceClient, profile);
    if (writable !== null && !writable.includes(companyId)) {
      return jsonResponse({ error: "Nu aveți drept de modificare pe această societate." }, 403);
    }

    const { data: company, error } = await serviceClient
      .from("companies")
      .select("id, denumire, cui")
      .eq("id", companyId)
      .maybeSingle();

    if (error || !company) {
      return jsonResponse({ error: "Societatea nu a fost găsită." }, 404);
    }

    const name = String(company.denumire ?? "").trim() || "—";
    const cui = String(company.cui ?? "").trim() || "—";
    const result = await sendResendEmail({
      to: [email],
      subject: `Cerere autorizare SPV e-Factura — ${name}`,
      text: [
        "Bună ziua,",
        "",
        "Vă rugăm să autorizați societatea de mai jos în SPV (RO e-Factura), cu semnătura dumneavoastră electronică:",
        "",
        `Denumire: ${name}`,
        `CUI: ${cui}`,
        "",
        "După autorizare, vă rugăm să ne comunicați data până la care autorizarea este valabilă.",
        "",
        "Vom trimite facturile emise din ERP Mobile ca XML UBL și PDF pe acest email, pentru încărcare în e-Factura.",
        "",
        "Vă mulțumim.",
      ].join("\n"),
    });

    if (!result.ok) {
      return jsonResponse({ error: result.error ?? "Emailul nu a putut fi trimis." }, 400);
    }

    return jsonResponse({ sent: true, to: email });
  } catch (err) {
    if (err instanceof Response) return err;
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});

function isEmail(value: string): boolean {
  if (value.length < 6 || value.length > 200 || value.includes(" ")) return false;
  const at = value.indexOf("@");
  return at > 0 && at < value.length - 1 && value.indexOf("@", at + 1) === -1 && value.includes(".");
}
