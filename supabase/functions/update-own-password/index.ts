import { handleCors } from "../_shared/cors.ts";
import { requireAuthenticatedUser, jsonResponse } from "../_shared/admin.ts";
import { generateSignupConfirmationLink } from "../_shared/auth-links.ts";
import { sendPasswordChangeConfirmation } from "../_shared/email.ts";

interface UpdateOwnPasswordPayload {
  parola: string;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  try {
    const { user, serviceClient } = await requireAuthenticatedUser(req);
    const body: UpdateOwnPasswordPayload = await req.json();
    const nextPassword = body.parola?.trim() ?? "";

    if (nextPassword.length < 6) {
      return jsonResponse({ error: "Parola trebuie să aibă minim 6 caractere." }, 400);
    }

    const { data: profile, error: fetchError } = await serviceClient
      .from("user_profiles")
      .select("nume, prenume, email, is_email_confirmed")
      .eq("id", user.id)
      .single();

    if (fetchError || !profile) {
      return jsonResponse({ error: "Profil negăsit" }, 404);
    }

    const { error: authError } = await serviceClient.auth.admin.updateUserById(user.id, {
      password: nextPassword,
      email_confirm: false,
    });

    if (authError) {
      return jsonResponse({ error: authError.message }, 400);
    }

    await serviceClient
      .from("user_profiles")
      .update({ is_email_confirmed: false })
      .eq("id", user.id);

    const linkResult = await generateSignupConfirmationLink(
      serviceClient,
      profile.email.trim(),
      nextPassword,
    );

    const emailResult = await sendPasswordChangeConfirmation({
      userEmail: profile.email.trim(),
      userFullName: `${profile.prenume} ${profile.nume}`,
      verificationLink: linkResult.link,
    });

    let emailStatus = emailResult.details;
    if (linkResult.error) {
      emailStatus = `${emailStatus} Eroare link: ${linkResult.error}`;
    }

    const { data: updatedProfile, error: profileFetchError } = await serviceClient
      .from("user_profiles")
      .select("*")
      .eq("id", user.id)
      .single();

    if (profileFetchError || !updatedProfile) {
      return jsonResponse({ error: "Profilul actualizat nu a putut fi citit" }, 500);
    }

    return jsonResponse({
      user: updatedProfile,
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
