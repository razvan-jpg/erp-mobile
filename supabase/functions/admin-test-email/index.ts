import { handleCors } from "../_shared/cors.ts";
import { requireAdmin, jsonResponse } from "../_shared/admin.ts";
import { getEmailFromAddress, sendResendEmail } from "../_shared/resend.ts";

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  try {
    await requireAdmin(req);
    const body = await req.json().catch(() => ({}));
    const to = (body.email as string)?.trim() || "ERPMobile@dateconta.ro";

    const result = await sendResendEmail({
      to: [to],
      subject: "Test ERP Mobile — Resend",
      text: "Dacă primiți acest email, configurația Resend funcționează corect.",
    });

    if (!result.ok) {
      return jsonResponse({
        sent: false,
        from: getEmailFromAddress(),
        error: result.error,
      }, 400);
    }

    return jsonResponse({
      sent: true,
      from: getEmailFromAddress(),
      to,
      message: "Email de test trimis cu succes.",
    });
  } catch (err) {
    if (err instanceof Response) return err;
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});
