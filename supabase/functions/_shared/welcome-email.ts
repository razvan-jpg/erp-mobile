import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { sendAccountActivatedEmail } from "./email.ts";

export async function processWelcomeEmailForUser(
  serviceClient: SupabaseClient,
  userId: string,
): Promise<{ status: string; email_sent?: boolean; email_details?: string; error?: string }> {
  const { data: authData, error: authError } = await serviceClient.auth.admin.getUserById(userId);
  if (authError || !authData.user) {
    return { status: "error", error: "Utilizator negăsit" };
  }

  let user = authData.user;
  if (!user.email_confirmed_at) {
    await new Promise((resolve) => setTimeout(resolve, 600));
    const { data: refreshed } = await serviceClient.auth.admin.getUserById(userId);
    if (refreshed?.user) {
      user = refreshed.user;
    }
  }

  if (!user.email_confirmed_at) {
    return { status: "skipped", error: "Email neconfirmat" };
  }

  const metadata = user.user_metadata ?? {};
  if (metadata.welcome_email_sent === true) {
    return { status: "already_sent" };
  }

  if (metadata.is_superadmin === true) {
    return { status: "skipped_superadmin" };
  }

  const { data: profile, error: profileError } = await serviceClient
    .from("user_profiles")
    .select("nume, prenume, cnp, email, telefon")
    .eq("id", userId)
    .single();

  if (profileError || !profile) {
    return { status: "error", error: "Profil negăsit" };
  }

  const adminEmail = (metadata.created_by_admin_email as string) ?? "";
  const moduleSummary = (metadata.module_permissions_summary as string) ?? "";
  const password = (metadata.pending_welcome_password as string) ?? "";

  const emailResult = await sendAccountActivatedEmail({
    userEmail: profile.email,
    userFullName: `${profile.prenume} ${profile.nume}`,
    userPassword: password,
    userCNP: profile.cnp,
    userPhone: profile.telefon ?? "",
    adminEmail,
    modulePermissionsSummary: moduleSummary,
  });

  const cleanedMetadata = { ...metadata, welcome_email_sent: true };
  delete cleanedMetadata.pending_welcome_password;

  await serviceClient.auth.admin.updateUserById(userId, {
    user_metadata: cleanedMetadata,
  });

  return {
    status: emailResult.sent ? "sent" : "email_failed",
    email_sent: emailResult.sent,
    email_details: emailResult.details,
  };
}
