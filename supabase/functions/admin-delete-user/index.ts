import { handleCors } from "../_shared/cors.ts";
import { requireAdmin, userBelongsToCallerWritableCompanies, jsonResponse } from "../_shared/admin.ts";

interface DeleteUserPayload {
  user_id: string;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  try {
    const { profile: callerProfile, serviceClient } = await requireAdmin(req);
    const body: DeleteUserPayload = await req.json();

    if (!body.user_id) {
      return jsonResponse({ error: "user_id obligatoriu" }, 400);
    }

    const { data: target } = await serviceClient
      .from("user_profiles")
      .select("is_admin, is_superadmin")
      .eq("id", body.user_id)
      .single();

    if (!target) {
      return jsonResponse({ error: "Utilizator negăsit" }, 404);
    }

    if (target.is_superadmin) {
      return jsonResponse({ error: "Superadmin-ul nu poate fi șters." }, 400);
    }

    if (target.is_admin) {
      return jsonResponse({ error: "Administratorul societății nu poate fi șters din aplicație." }, 400);
    }

    if (!callerProfile.is_superadmin) {
      const belongs = await userBelongsToCallerWritableCompanies(
        serviceClient,
        callerProfile,
        body.user_id,
      );
      if (!belongs) {
        return jsonResponse({ error: "Utilizatorul nu aparține societăților pe care le administrați." }, 403);
      }
    }

    const { error: deleteError } = await serviceClient.auth.admin.deleteUser(body.user_id);

    if (deleteError) {
      return jsonResponse({ error: deleteError.message }, 400);
    }

    return jsonResponse({ status: "deleted", user_id: body.user_id });
  } catch (err) {
    if (err instanceof Response) return err;
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});
