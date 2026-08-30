import { handleCors } from "../_shared/cors.ts";
import {
  requireAdmin,
  getCallerWritableCompanyIds,
  filterCompanyPermissionsToWritableCompanies,
  userBelongsToCallerWritableCompanies,
  jsonResponse,
} from "../_shared/admin.ts";
import {
  generateMagicLinkConfirmation,
  generateSignupConfirmationLink,
} from "../_shared/auth-links.ts";
import { sendEmailChangeVerification } from "../_shared/email.ts";
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

interface UpdateUserPayload {
  user_id: string;
  nume?: string;
  prenume?: string;
  cnp?: string;
  email?: string;
  telefon?: string;
  parola?: string;
  permissions?: PermissionInput[];
  company_permissions?: CompanyPermissionInput[];
}

async function replaceCompanyPermissions(
  serviceClient: ReturnType<typeof import("../_shared/admin.ts").getServiceClient>,
  userId: string,
  permissions: CompanyPermissionInput[],
  scopedCompanyIds: string[] | null,
) {
  if (scopedCompanyIds === null) {
    await serviceClient
      .from("user_company_permissions")
      .delete()
      .eq("user_id", userId);
  } else if (scopedCompanyIds.length > 0) {
    await serviceClient
      .from("user_company_permissions")
      .delete()
      .eq("user_id", userId)
      .in("company_id", scopedCompanyIds);
  }

  if (permissions.length === 0) {
    return;
  }

  const companyRows = permissions.map((p) => ({
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
    throw new Error(companyPermError.message);
  }
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  try {
    const { user: adminUser, profile: callerProfile, serviceClient } = await requireAdmin(req);
    const body: UpdateUserPayload = await req.json();
    const writableCompanyIds = await getCallerWritableCompanyIds(serviceClient, callerProfile);

    if (!body.user_id) {
      return jsonResponse({ error: "user_id obligatoriu" }, 400);
    }

    const { data: current, error: fetchError } = await serviceClient
      .from("user_profiles")
      .select("nume, prenume, cnp, email, telefon, is_admin, is_superadmin, is_blocked")
      .eq("id", body.user_id)
      .single();

    if (fetchError || !current) {
      return jsonResponse({ error: "Utilizator negăsit" }, 404);
    }

    if (current.is_superadmin && !callerProfile.is_superadmin) {
      return jsonResponse({ error: "Nu puteți modifica Superadmin-ul." }, 403);
    }

    if (current.is_admin && !current.is_superadmin && !callerProfile.is_superadmin) {
      return jsonResponse({ error: "Nu puteți modifica administratorul societății." }, 403);
    }

    if (!callerProfile.is_superadmin) {
      if ((writableCompanyIds?.length ?? 0) === 0) {
        return jsonResponse({ error: "Nu administrați nicio societate." }, 403);
      }
      const belongs = await userBelongsToCallerWritableCompanies(
        serviceClient,
        callerProfile,
        body.user_id,
      );
      if (!belongs) {
        return jsonResponse({ error: "Utilizatorul nu aparține societăților pe care le administrați." }, 403);
      }
    }

    const nextCNP = (body.cnp ?? current.cnp).trim();
    if (body.cnp && !isValidCNP(nextCNP)) {
      return jsonResponse({
        error: "CNP invalid. Introduceți un CNP valid de 13 cifre sau 0000000000000 dacă nu se divulgă (GDPR).",
      }, 400);
    }

    const nextProfile = {
      nume: body.nume ?? current.nume,
      prenume: body.prenume ?? current.prenume,
      cnp: nextCNP,
      email: body.email ?? current.email,
      telefon: body.telefon ?? current.telefon ?? "",
    };

    const { error: profileError } = await serviceClient
      .from("user_profiles")
      .update(nextProfile)
      .eq("id", body.user_id);

    if (profileError) {
      return jsonResponse({ error: profileError.message }, 400);
    }

    const authUpdate: {
      email?: string;
      email_confirm?: boolean;
      password?: string;
      user_metadata: Record<string, unknown>;
    } = {
      user_metadata: {
        nume: nextProfile.nume,
        prenume: nextProfile.prenume,
        cnp: nextProfile.cnp,
        telefon: nextProfile.telefon,
        is_admin: current.is_admin,
        is_blocked: current.is_blocked,
      },
    };

    const emailChanged = Boolean(body.email && body.email !== current.email);
    const nextPassword = body.parola && body.parola.length > 0 ? body.parola : undefined;

    if (emailChanged) {
      authUpdate.email = body.email;
      authUpdate.email_confirm = false;
    }

    if (nextPassword) {
      authUpdate.password = nextPassword;
    }

    const { error: authError } = await serviceClient.auth.admin.updateUserById(
      body.user_id,
      authUpdate
    );

    if (authError) {
      return jsonResponse({ error: authError.message }, 400);
    }

    if (emailChanged && !current.is_admin) {
      await serviceClient
        .from("user_profiles")
        .update({ is_email_confirmed: false })
        .eq("id", body.user_id);

      const { data: adminProfile } = await serviceClient
        .from("user_profiles")
        .select("nume, prenume, email")
        .eq("id", adminUser.id)
        .single();

      const linkResult = nextPassword
        ? await generateSignupConfirmationLink(serviceClient, body.email!.trim(), nextPassword)
        : await generateMagicLinkConfirmation(serviceClient, body.email!.trim());
      const verificationLink = linkResult.link;

      const emailResult = await sendEmailChangeVerification({
        userEmail: body.email!.trim(),
        userFullName: `${nextProfile.prenume} ${nextProfile.nume}`,
        verificationLink,
        adminEmail: adminProfile?.email ?? "",
        adminFullName: adminProfile
          ? `${adminProfile.prenume} ${adminProfile.nume}`
          : "Administrator",
      });

      const { data: profileAfterEmail, error: profileAfterEmailError } = await serviceClient
        .from("user_profiles")
        .select("*")
        .eq("id", body.user_id)
        .single();

      if (profileAfterEmailError || !profileAfterEmail) {
        return jsonResponse({ error: "Profilul actualizat nu a putut fi citit" }, 500);
      }

      return jsonResponse({
        user: profileAfterEmail,
        email_changed: true,
        email_status: emailResult.details,
        emails_sent: emailResult.sent,
        verification_link: verificationLink,
      });
    }

    if (body.permissions !== undefined && !current.is_admin) {
      await serviceClient
        .from("user_module_permissions")
        .delete()
        .eq("user_id", body.user_id);

      if (body.permissions.length > 0) {
        const rows = body.permissions.map((p) => ({
          user_id: body.user_id,
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
          return jsonResponse({ error: permError.message }, 400);
        }
      }
    }

    if (body.company_permissions !== undefined) {
      const scopedPermissions = filterCompanyPermissionsToWritableCompanies(
        body.company_permissions,
        writableCompanyIds,
      );

      try {
        await replaceCompanyPermissions(
          serviceClient,
          body.user_id,
          scopedPermissions,
          writableCompanyIds,
        );
      } catch (error) {
        const message = error instanceof Error ? error.message : "Eroare la salvarea drepturilor pe societăți.";
        return jsonResponse({ error: message }, 400);
      }
    }

    const { data: profile, error: profileFetchError } = await serviceClient
      .from("user_profiles")
      .select("*")
      .eq("id", body.user_id)
      .single();

    if (profileFetchError || !profile) {
      return jsonResponse({ error: "Profilul actualizat nu a putut fi citit" }, 500);
    }

    return jsonResponse({ user: profile });
  } catch (err) {
    if (err instanceof Response) return err;
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});
