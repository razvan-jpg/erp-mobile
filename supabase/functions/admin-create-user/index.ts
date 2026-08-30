import { handleCors } from "../_shared/cors.ts";
import {
  requireAdmin,
  getCallerWritableCompanyIds,
  filterCompanyPermissionsToWritableCompanies,
  jsonResponse,
} from "../_shared/admin.ts";
import { generateSignupConfirmationLink } from "../_shared/auth-links.ts";
import { sendAccountCreatedEmails } from "../_shared/email.ts";
import { isValidCNP } from "../_shared/validators.ts";

interface PermissionInput {
  module_id: string;
  can_view?: boolean;
  can_create?: boolean;
  can_edit?: boolean;
  can_delete?: boolean;
}

interface CompanyPermissionInput {
  company_id: string;
  can_view?: boolean;
  can_create?: boolean;
  can_edit?: boolean;
  can_delete?: boolean;
}

interface CreateUserPayload {
  nume: string;
  prenume: string;
  cnp: string;
  email: string;
  telefon?: string;
  parola: string;
  permissions?: PermissionInput[];
  company_permissions?: CompanyPermissionInput[];
  admin_email?: string;
  module_permissions_summary?: string;
  company_permissions_summary?: string;
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  try {
    const { user: adminUser, profile: callerProfile, serviceClient } = await requireAdmin(req);
    const body: CreateUserPayload = await req.json();
    const writableCompanyIds = await getCallerWritableCompanyIds(serviceClient, callerProfile);

    const missing: string[] = [];
    if (!body.nume?.trim()) missing.push("Nume");
    if (!body.prenume?.trim()) missing.push("Prenume");
    if (!body.cnp?.trim()) missing.push("CNP");
    if (!body.email?.trim()) missing.push("Email");
    if (!body.parola?.trim()) missing.push("Parolă");

    if (missing.length > 0) {
      return jsonResponse({
        error: `Câmpuri obligatorii lipsă: ${missing.join(", ")}`,
      }, 400);
    }

    if (!isValidCNP(body.cnp.trim())) {
      return jsonResponse({
        error: "CNP invalid. Introduceți un CNP valid de 13 cifre sau 0000000000000 dacă nu se divulgă (GDPR).",
      }, 400);
    }

    if (body.parola.length < 6) {
      return jsonResponse({
        error: "Parola trebuie să aibă minim 6 caractere.",
      }, 400);
    }

    const { data: authData, error: authError } = await serviceClient.auth.admin.createUser({
      email: body.email.trim(),
      password: body.parola,
      email_confirm: false,
      user_metadata: {
        nume: body.nume.trim(),
        prenume: body.prenume.trim(),
        cnp: body.cnp.trim(),
        telefon: body.telefon?.trim() ?? "",
        is_admin: false,
        is_blocked: false,
        welcome_email_sent: false,
        created_by_admin_email: body.admin_email ?? adminUser.email ?? "",
        module_permissions_summary: body.module_permissions_summary ?? "",
        pending_welcome_password: body.parola,
      },
    });

    if (authError) {
      const message = authError.message.includes("duplicate")
        ? "Există deja un utilizator cu acest email sau cu același CNP (exceptând 0000000000000)."
        : authError.message;
      return jsonResponse({ error: message }, 400);
    }

    const userId = authData.user.id;

    if (body.permissions && body.permissions.length > 0) {
      const rows = body.permissions.map((p) => ({
        user_id: userId,
        module_id: p.module_id,
        can_view: p.can_view ?? false,
        can_create: p.can_create ?? false,
        can_edit: p.can_edit ?? false,
        can_delete: p.can_delete ?? false,
      }));

      const { error: permError } = await serviceClient
        .from("user_module_permissions")
        .insert(rows);

      if (permError) {
        await serviceClient.auth.admin.deleteUser(userId);
        return jsonResponse({ error: permError.message }, 400);
      }
    }

    let companyPermissions = filterCompanyPermissionsToWritableCompanies(
      body.company_permissions ?? [],
      writableCompanyIds,
    );

    if (!callerProfile.is_superadmin) {
      if ((writableCompanyIds?.length ?? 0) === 0) {
        await serviceClient.auth.admin.deleteUser(userId);
        return jsonResponse({ error: "Nu administrați nicio societate." }, 403);
      }
      if (companyPermissions.length === 0) {
        await serviceClient.auth.admin.deleteUser(userId);
        return jsonResponse({
          error: "Administratorul poate aloca drepturi doar pe societățile la care are acces de scriere.",
        }, 400);
      }
    }

    if (companyPermissions.length > 0) {
      const companyRows = companyPermissions.map((p) => ({
        user_id: userId,
        company_id: p.company_id,
        can_view: p.can_view ?? false,
        can_create: p.can_create ?? false,
        can_edit: p.can_edit ?? false,
        can_delete: p.can_delete ?? false,
      }));

      const { error: companyPermError } = await serviceClient
        .from("user_company_permissions")
        .insert(companyRows);

      if (companyPermError) {
        await serviceClient.auth.admin.deleteUser(userId);
        return jsonResponse({ error: companyPermError.message }, 400);
      }
    }

    const { data: profile, error: profileError } = await serviceClient
      .from("user_profiles")
      .select("*")
      .eq("id", userId)
      .single();

    if (profileError || !profile) {
      return jsonResponse({ error: "Utilizator creat, dar profilul nu a putut fi citit." }, 500);
    }

    await serviceClient
      .from("user_profiles")
      .update({ is_email_confirmed: false })
      .eq("id", userId);

    const { link: verificationLink, error: linkError } = await generateSignupConfirmationLink(
      serviceClient,
      body.email.trim(),
      body.parola,
    );

    const adminEmail = body.admin_email ?? adminUser.email ?? "";
    const { data: adminProfile } = await serviceClient
      .from("user_profiles")
      .select("nume, prenume, email")
      .eq("id", adminUser.id)
      .single();

    const emailResult = await sendAccountCreatedEmails({
      userEmail: body.email.trim(),
      userFullName: `${body.prenume.trim()} ${body.nume.trim()}`,
      userPassword: body.parola,
      userCNP: body.cnp.trim(),
      userPhone: body.telefon?.trim() ?? "",
      adminEmail,
      adminFullName: adminProfile
        ? `${adminProfile.prenume} ${adminProfile.nume}`
        : "Administrator",
      modulePermissionsSummary: body.module_permissions_summary ?? "",
      verificationLink,
    });

    const { data: updatedProfile } = await serviceClient
      .from("user_profiles")
      .select("*")
      .eq("id", userId)
      .single();

    let emailStatus = emailResult.details;
    if (linkError) {
      emailStatus = `${emailStatus} Eroare link confirmare: ${linkError}`;
    }

    return jsonResponse({
      user: updatedProfile ?? profile,
      email_status: emailStatus,
      emails_sent: emailResult.sent,
      email_verification_required: true,
      verification_link: verificationLink ?? undefined,
    }, 201);
  } catch (err) {
    if (err instanceof Response) return err;
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});
