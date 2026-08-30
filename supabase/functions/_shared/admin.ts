import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

export function getServiceClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}

export function getUserClient(authHeader: string) {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    {
      global: { headers: { Authorization: authHeader } },
      auth: { autoRefreshToken: false, persistSession: false },
    }
  );
}

async function fetchCallerProfile(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    throw new Response(JSON.stringify({ error: "Lipsă autorizare" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const userClient = getUserClient(authHeader);
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) {
    throw new Response(JSON.stringify({ error: "Token invalid" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const serviceClient = getServiceClient();
  const { data: profile, error: profileError } = await serviceClient
    .from("user_profiles")
    .select("id, email, is_admin, is_superadmin, is_blocked")
    .eq("id", user.id)
    .single();

  if (profileError || !profile) {
    throw new Response(JSON.stringify({ error: "Profil negăsit" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (profile.is_blocked) {
    throw new Response(JSON.stringify({ error: "Cont blocat" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }

  return { user, profile, serviceClient };
}

export async function requireAuthenticatedUser(req: Request) {
  return fetchCallerProfile(req);
}

export async function requireSuperAdmin(req: Request) {
  const context = await fetchCallerProfile(req);
  if (!context.profile.is_superadmin) {
    throw new Response(JSON.stringify({ error: "Acces interzis — doar Superadmin" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  return context;
}

export async function requireAdmin(req: Request) {
  const context = await fetchCallerProfile(req);
  if (!context.profile.is_superadmin && !context.profile.is_admin) {
    throw new Response(JSON.stringify({ error: "Acces interzis — doar Administrator" }), {
      status: 403,
      headers: { "Content-Type": "application/json" },
    });
  }
  return context;
}

export async function getManagedCompanyIds(
  serviceClient: ReturnType<typeof getServiceClient>,
  userId: string,
): Promise<string[]> {
  const { data } = await serviceClient
    .from("companies")
    .select("id")
    .eq("admin_user_id", userId);

  return (data ?? []).map((row) => row.id as string);
}

export async function getManagedCompanyId(
  serviceClient: ReturnType<typeof getServiceClient>,
  userId: string,
): Promise<string | null> {
  const managedCompanyIds = await getManagedCompanyIds(serviceClient, userId);
  return managedCompanyIds[0] ?? null;
}

function hasWriteCompanyPermission(permission: {
  can_create?: boolean;
  can_edit?: boolean;
  can_delete?: boolean;
}): boolean {
  return Boolean(permission.can_create || permission.can_edit || permission.can_delete);
}

export async function getCallerWritableCompanyIds(
  serviceClient: ReturnType<typeof getServiceClient>,
  callerProfile: { id: string; is_superadmin: boolean },
): Promise<string[] | null> {
  if (callerProfile.is_superadmin) {
    return null;
  }

  const managedCompanyIds = await getManagedCompanyIds(serviceClient, callerProfile.id);
  const { data: permissions } = await serviceClient
    .from("user_company_permissions")
    .select("company_id, can_create, can_edit, can_delete")
    .eq("user_id", callerProfile.id);

  const permissionCompanyIds = (permissions ?? [])
    .filter(hasWriteCompanyPermission)
    .map((row) => row.company_id as string);

  return [...new Set([...managedCompanyIds, ...permissionCompanyIds])];
}

export async function userBelongsToCallerWritableCompanies(
  serviceClient: ReturnType<typeof getServiceClient>,
  callerProfile: { id: string; is_superadmin: boolean },
  userId: string,
): Promise<boolean> {
  const writableCompanyIds = await getCallerWritableCompanyIds(serviceClient, callerProfile);
  if (writableCompanyIds === null) {
    return true;
  }
  if (writableCompanyIds.length === 0) {
    return false;
  }

  const { data: membership } = await serviceClient
    .from("user_company_permissions")
    .select("id")
    .eq("user_id", userId)
    .in("company_id", writableCompanyIds)
    .limit(1);

  return (membership?.length ?? 0) > 0;
}

export function filterCompanyPermissionsToWritableCompanies<T extends { company_id: string }>(
  permissions: T[],
  writableCompanyIds: string[] | null,
): T[] {
  if (writableCompanyIds === null) {
    return permissions;
  }
  return permissions.filter((permission) => writableCompanyIds.includes(permission.company_id));
}

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export async function findUserProfileByEmail(
  serviceClient: ReturnType<typeof getServiceClient>,
  email: string,
) {
  const normalizedEmail = email.trim().toLowerCase();
  if (!normalizedEmail) {
    return null;
  }

  const { data, error } = await serviceClient
    .from("user_profiles")
    .select("id, email, nume, prenume, is_superadmin, is_blocked, is_email_confirmed")
    .ilike("email", normalizedEmail)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  return data;
}
