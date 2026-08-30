import { handleCors } from "../_shared/cors.ts";
import { requireAdmin, userBelongsToCallerWritableCompanies, jsonResponse } from "../_shared/admin.ts";
import { generateMagicLinkConfirmation } from "../_shared/auth-links.ts";
import { sendConfirmationResend } from "../_shared/email.ts";

interface ResendConfirmationPayload {
  user_id: string;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  try {
    const { user: adminUser, profile: callerProfile, serviceClient } = await requireAdmin(req);
    const body: ResendConfirmationPayload = await req.json();

    if (!body.user_id) {
      return jsonResponse({ error: "user_id obligatoriu" }, 400);
    }

    const { data: target, error: fetchError } = await serviceClient
      .from("user_profiles")
      .select("nume, prenume, email, is_admin, is_superadmin, is_email_confirmed")
      .eq("id", body.user_id)
      .single();

    if (fetchError || !target) {
      return jsonResponse({ error: "Utilizator negăsit" }, 404);
    }

    if (target.is_superadmin) {
      return jsonResponse({ error: "Nu puteți retrimite confirmarea pentru superadmin." }, 400);
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

    await serviceClient
      .from("user_profiles")
      .update({ is_email_confirmed: false })
      .eq("id", body.user_id);

    await serviceClient.auth.admin.updateUserById(body.user_id, {
      email_confirm: false,
    });

    const linkResult = await generateMagicLinkConfirmation(
      serviceClient,
      target.email.trim(),
    );

    const { data: adminProfile } = await serviceClient
      .from("user_profiles")
      .select("nume, prenume, email")
      .eq("id", adminUser.id)
      .single();

    const emailResult = await sendConfirmationResend({
      userEmail: target.email.trim(),
      userFullName: `${target.prenume} ${target.nume}`,
      verificationLink: linkResult.link,
      adminEmail: adminProfile?.email ?? "",
      adminFullName: adminProfile
        ? `${adminProfile.prenume} ${adminProfile.nume}`
        : "Administrator",
    });

    let emailStatus = emailResult.details;
    if (linkResult.error) {
      emailStatus = `${emailStatus} Eroare link: ${linkResult.error}`;
    }

    const { data: profile } = await serviceClient
      .from("user_profiles")
      .select("*")
      .eq("id", body.user_id)
      .single();

    return jsonResponse({
      user: profile,
      email_status: emailStatus,
      emails_sent: emailResult.sent,
      verification_link: linkResult.link,
    });
  } catch (err) {
    if (err instanceof Response) return err;
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});
