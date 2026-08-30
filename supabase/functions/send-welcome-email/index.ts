import { handleCors } from "../_shared/cors.ts";
import { getServiceClient, jsonResponse } from "../_shared/admin.ts";
import { processWelcomeEmailForUser } from "../_shared/welcome-email.ts";

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  const triggerSecret = Deno.env.get("WELCOME_TRIGGER_SECRET") ?? "";
  const incomingSecret = req.headers.get("x-trigger-secret") ?? "";
  if (!triggerSecret || incomingSecret !== triggerSecret) {
    return jsonResponse({ error: "Neautorizat" }, 401);
  }

  try {
    const body = await req.json();
    const userId = body.user_id as string;
    if (!userId) {
      return jsonResponse({ error: "user_id obligatoriu" }, 400);
    }

    const result = await processWelcomeEmailForUser(getServiceClient(), userId);

    return jsonResponse({
      ok: result.status !== "error",
      ...result,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});
