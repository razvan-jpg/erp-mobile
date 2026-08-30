import { handleCors } from "../_shared/cors.ts";
import { requireAdmin, userBelongsToCallerWritableCompanies, jsonResponse } from "../_shared/admin.ts";

interface ToggleBlockPayload {
  user_id: string;
  is_blocked: boolean;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  try {
    const { profile: callerProfile, serviceClient } = await requireAdmin(req);
    const body: ToggleBlockPayload = await req.json();

    if (!body.user_id || body.is_blocked === undefined) {
      return jsonResponse({ error: "user_id și is_blocked obligatorii" }, 400);
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
      return jsonResponse({ error: "Nu puteți bloca superadmin-ul." }, 400);
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

    const { error: profileError } = await serviceClient
      .from("user_profiles")
      .update({ is_blocked: body.is_blocked })
      .eq("id", body.user_id);

    if (profileError) {
      return jsonResponse({ error: profileError.message }, 400);
    }

    if (body.is_blocked) {
      await serviceClient.auth.admin.updateUserById(body.user_id, {
        ban_duration: "876000h",
      });
    } else {
      await serviceClient.auth.admin.updateUserById(body.user_id, {
        ban_duration: "none",
      });
    }

    const { data: profile } = await serviceClient
      .from("user_profiles")
      .select("*")
      .eq("id", body.user_id)
      .single();

    return jsonResponse({ user: profile });
  } catch (err) {
    if (err instanceof Response) return err;
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});
