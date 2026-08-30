import { handleCors } from "../_shared/cors.ts";
import {
  requireSuperAdmin,
  jsonResponse,
  findUserProfileByEmail,
} from "../_shared/admin.ts";
import { generateSignupConfirmationLink } from "../_shared/auth-links.ts";
import { sendAccountCreatedEmails } from "../_shared/email.ts";
import { isValidCNP } from "../_shared/validators.ts";

interface CompanyInput {
  denumire: string;
  cui?: string;
  nr_reg_com?: string;
  adresa?: string;
  iban?: string;
  email?: string;
  telefon?: string;
  is_active?: boolean;
  platitor_tva?: boolean;
}

interface CompanyAdminInput {
  nume: string;
  prenume: string;
  email: string;
  parola?: string;
  cnp?: string;
  telefon?: string;
}

interface CreateCompanyPayload {
  company: CompanyInput;
  company_admin: CompanyAdminInput;
}

async function rollbackCreatedCompany(
  serviceClient: ReturnType<typeof import("../_shared/admin.ts").getServiceClient>,
  companyId: string,
  adminUserId?: string,
  deleteAdminUser = false,
) {
  if (deleteAdminUser && adminUserId) {
    await serviceClient.auth.admin.deleteUser(adminUserId);
  }
  await serviceClient.from("companies").delete().eq("id", companyId);
}

async function grantCompanyAdminAccess(
  serviceClient: ReturnType<typeof import("../_shared/admin.ts").getServiceClient>,
  adminUserId: string,
  companyId: string,
) {
  const { error: linkError } = await serviceClient
    .from("companies")
    .update({ admin_user_id: adminUserId })
    .eq("id", companyId);

  if (linkError) {
    throw new Error(linkError.message);
  }

  const { error: companyPermError } = await serviceClient
    .from("user_company_permissions")
    .upsert(
      {
        user_id: adminUserId,
        company_id: companyId,
        can_view: true,
        can_create: true,
        can_edit: true,
        can_delete: true,
      },
      { onConflict: "user_id,company_id" },
    );

  if (companyPermError) {
    throw new Error(companyPermError.message);
  }

  const { data: modules } = await serviceClient
    .from("modules")
    .select("id")
    .eq("is_active", true);

  if (modules && modules.length > 0) {
    const moduleRows = modules.map((module) => ({
      user_id: adminUserId,
      module_id: module.id,
      can_view: true,
      can_create: true,
      can_edit: true,
      can_delete: true,
    }));

    const { error: modulePermError } = await serviceClient
      .from("user_module_permissions")
      .upsert(moduleRows, { onConflict: "user_id,module_id" });

    if (modulePermError) {
      throw new Error(modulePermError.message);
    }
  }
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  try {
    const { user: superadmin, serviceClient } = await requireSuperAdmin(req);
    const body: CreateCompanyPayload = await req.json();

    const company = body.company;
    const admin = body.company_admin;

    if (!company?.denumire?.trim()) {
      return jsonResponse({ error: "Denumirea societății este obligatorie." }, 400);
    }

    const missing: string[] = [];
    if (!admin?.nume?.trim()) missing.push("Nume admin");
    if (!admin?.prenume?.trim()) missing.push("Prenume admin");
    if (!admin?.email?.trim()) missing.push("Email admin");
    if (missing.length > 0) {
      return jsonResponse({ error: `Câmpuri obligatorii lipsă: ${missing.join(", ")}` }, 400);
    }

    const adminEmail = admin.email.trim();
    const existingProfile = await findUserProfileByEmail(serviceClient, adminEmail);

    if (existingProfile?.is_superadmin) {
      return jsonResponse({
        error: "Superadminul nu poate fi desemnat administrator de societate.",
      }, 400);
    }

    if (existingProfile?.is_blocked) {
      return jsonResponse({
        error: "Utilizatorul existent este blocat și nu poate fi alocat ca administrator.",
      }, 400);
    }

    if (!existingProfile) {
      if (!admin?.parola?.trim()) {
        missing.push("Parolă admin");
      }
      if (missing.length > 0) {
        return jsonResponse({ error: `Câmpuri obligatorii lipsă: ${missing.join(", ")}` }, 400);
      }

      const adminCNP = (admin.cnp ?? "0000000000000").trim();
      if (!isValidCNP(adminCNP)) {
        return jsonResponse({ error: "CNP admin invalid." }, 400);
      }

      if ((admin.parola ?? "").length < 6) {
        return jsonResponse({ error: "Parola admin trebuie să aibă minim 6 caractere." }, 400);
      }
    }

    const { data: createdCompany, error: companyError } = await serviceClient
      .from("companies")
      .insert({
        denumire: company.denumire.trim(),
        cui: company.cui?.trim() || null,
        nr_reg_com: company.nr_reg_com?.trim() || null,
        adresa: company.adresa?.trim() || null,
        iban: company.iban?.trim() || null,
        email: company.email?.trim() || null,
        telefon: company.telefon?.trim() || null,
        is_active: company.is_active ?? true,
        platitor_tva: company.platitor_tva ?? true,
      })
      .select("*")
      .single();

    if (companyError || !createdCompany) {
      return jsonResponse({ error: companyError?.message ?? "Societatea nu a putut fi creată." }, 400);
    }

    if (existingProfile) {
      const adminUserId = existingProfile.id;

      try {
        await serviceClient.auth.admin.updateUserById(adminUserId, {
          email_confirm: true,
          user_metadata: {
            is_admin: true,
            is_superadmin: false,
          },
        });

        const { error: profileError } = await serviceClient
          .from("user_profiles")
          .update({
            is_admin: true,
            is_superadmin: false,
            is_email_confirmed: true,
            selected_company_id: createdCompany.id,
          })
          .eq("id", adminUserId);

        if (profileError) {
          throw new Error(profileError.message);
        }

        await grantCompanyAdminAccess(serviceClient, adminUserId, createdCompany.id);
      } catch (linkError) {
        await rollbackCreatedCompany(serviceClient, createdCompany.id);
        const message = linkError instanceof Error ? linkError.message : "Alocarea administratorului a eșuat.";
        return jsonResponse({ error: message }, 400);
      }

      const { data: finalCompany } = await serviceClient
        .from("companies")
        .select("*")
        .eq("id", createdCompany.id)
        .single();

      return jsonResponse({
        company: finalCompany ?? createdCompany,
        company_admin_id: adminUserId,
        existing_admin_linked: true,
        email_verification_required: false,
      }, 201);
    }

    const adminCNP = (admin.cnp ?? "0000000000000").trim();
    const adminPassword = admin.parola!.trim();

    const { data: authData, error: authError } = await serviceClient.auth.admin.createUser({
      email: adminEmail,
      password: adminPassword,
      email_confirm: false,
      user_metadata: {
        nume: admin.nume.trim(),
        prenume: admin.prenume.trim(),
        cnp: adminCNP,
        telefon: admin.telefon?.trim() ?? "",
        is_admin: true,
        is_superadmin: false,
        is_blocked: false,
        welcome_email_sent: false,
        created_by_admin_email: superadmin.email ?? "",
        pending_welcome_password: adminPassword,
      },
    });

    if (authError) {
      await rollbackCreatedCompany(serviceClient, createdCompany.id);
      return jsonResponse({ error: authError.message }, 400);
    }

    const adminUserId = authData.user.id;

    try {
      await grantCompanyAdminAccess(serviceClient, adminUserId, createdCompany.id);

      const { error: profileError } = await serviceClient
        .from("user_profiles")
        .update({
          is_admin: true,
          is_superadmin: false,
          is_email_confirmed: false,
          selected_company_id: createdCompany.id,
        })
        .eq("id", adminUserId);

      if (profileError) {
        throw new Error(profileError.message);
      }
    } catch (linkError) {
      await rollbackCreatedCompany(serviceClient, createdCompany.id, adminUserId, true);
      const message = linkError instanceof Error ? linkError.message : "Alocarea administratorului a eșuat.";
      return jsonResponse({ error: message }, 400);
    }

    const { link: verificationLink } = await generateSignupConfirmationLink(
      serviceClient,
      adminEmail,
      adminPassword,
    );

    await sendAccountCreatedEmails({
      userEmail: adminEmail,
      userFullName: `${admin.prenume.trim()} ${admin.nume.trim()}`,
      userPassword: adminPassword,
      userCNP: adminCNP,
      userPhone: admin.telefon?.trim() ?? "",
      adminEmail: superadmin.email ?? "",
      adminFullName: "Superadmin",
      modulePermissionsSummary: "Administrator societate — acces complet în societatea creată.",
      verificationLink,
    });

    const { data: finalCompany } = await serviceClient
      .from("companies")
      .select("*")
      .eq("id", createdCompany.id)
      .single();

    return jsonResponse({
      company: finalCompany ?? createdCompany,
      company_admin_id: adminUserId,
      existing_admin_linked: false,
      email_verification_required: true,
    }, 201);
  } catch (err) {
    if (err instanceof Response) return err;
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});
