import { corsHeaders, handleCors } from "../_shared/cors.ts";
import { getServiceClient, jsonResponse } from "../_shared/admin.ts";

const SUPERADMIN_EMAIL = "razvan.ivan@icloud.com";
const SUPERADMIN_PASSWORD = "David12!";

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const serviceClient = getServiceClient();

    const { data: existingSuperadmin } = await serviceClient
      .from("user_profiles")
      .select("id, email")
      .eq("is_superadmin", true)
      .limit(1)
      .maybeSingle();

    if (existingSuperadmin) {
      return jsonResponse({
        status: "already_exists",
        email: existingSuperadmin.email,
      });
    }

    const { data: authData, error: authError } = await serviceClient.auth.admin.createUser({
      email: SUPERADMIN_EMAIL,
      password: SUPERADMIN_PASSWORD,
      email_confirm: true,
      user_metadata: {
        nume: "Ivan",
        prenume: "Razvan",
        cnp: "0000000000000",
        telefon: "",
        is_admin: true,
        is_superadmin: true,
        is_blocked: false,
      },
    });

    if (authError) {
      return jsonResponse({ error: authError.message }, 400);
    }

    await serviceClient
      .from("user_profiles")
      .update({ is_superadmin: true, is_admin: true, is_email_confirmed: true })
      .eq("id", authData.user.id);

    return jsonResponse({
      status: "created",
      email: SUPERADMIN_EMAIL,
      message: "Superadmin creat. Schimbați parola la primul login.",
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});
