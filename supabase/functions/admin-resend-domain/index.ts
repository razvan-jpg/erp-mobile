import { handleCors } from "../_shared/cors.ts";
import { requireAdmin, jsonResponse } from "../_shared/admin.ts";

const DOMAIN = "dateconta.ro";

async function resendRequest(
  path: string,
  init: RequestInit = {},
): Promise<{ ok: boolean; status: number; data?: unknown; error?: string }> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    return { ok: false, status: 500, error: "RESEND_API_KEY lipsește." };
  }

  const response = await fetch(`https://api.resend.com${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });

  const text = await response.text();
  let data: unknown = text;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    // keep raw text
  }

  if (!response.ok) {
    return {
      ok: false,
      status: response.status,
      data,
      error: typeof data === "object" && data && "message" in data
        ? String((data as { message?: string }).message)
        : text,
    };
  }

  return { ok: true, status: response.status, data };
}

Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodă nepermisă" }, 405);
  }

  try {
    await requireAdmin(req);

    const list = await resendRequest("/domains");
    if (!list.ok) {
      return jsonResponse({ error: list.error, details: list.data }, list.status);
    }

    const domains = (list.data as { data?: Array<Record<string, unknown>> })?.data ?? [];
    let domain = domains.find((item) => item.name === DOMAIN);

    if (!domain) {
      const created = await resendRequest("/domains", {
        method: "POST",
        body: JSON.stringify({ name: DOMAIN }),
      });
      if (!created.ok) {
        return jsonResponse({ error: created.error, details: created.data }, created.status);
      }
      domain = created.data as Record<string, unknown>;
    }

    const domainId = domain?.id as string | undefined;
    if (!domainId) {
      return jsonResponse({ error: "Nu am putut determina ID-ul domeniului." }, 500);
    }

    const details = await resendRequest(`/domains/${domainId}`);
    if (!details.ok) {
      return jsonResponse({ error: details.error, details: details.data }, details.status);
    }

    return jsonResponse({
      domain: DOMAIN,
      status: (details.data as { status?: string })?.status ?? domain.status ?? "unknown",
      records: (details.data as { records?: unknown[] })?.records ?? [],
      message:
        "Adăugați recordurile DNS în cPanel → Zone Editor, apoi apăsați Verify în Resend.",
    });
  } catch (err) {
    if (err instanceof Response) return err;
    const message = err instanceof Error ? err.message : "Eroare necunoscută";
    return jsonResponse({ error: message }, 500);
  }
});
