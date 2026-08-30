import { handleCors } from "../_shared/cors.ts";
import { getServiceClient, getUserClient, jsonResponse } from "../_shared/admin.ts";
import { processWelcomeEmailForUser } from "../_shared/welcome-email.ts";

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse({ error: "Token lipsă" }, 401);
    }

    const userClient = getUserClient(authHeader);
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return jsonResponse({ error: "Token invalid sau expirat" }, 401);
    }

    const result = await processWelcomeEmailForUser(getServiceClient(), user.id);

    return jsonResponse({
      ok: true,
      confirmed: true,
      ...result,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});
