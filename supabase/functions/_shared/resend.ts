export function getEmailFromAddress(): string {
  const raw = Deno.env.get("EMAIL_FROM")?.trim();
  if (!raw) return "ERP Mobile <ERPMobile@dateconta.ro>";
  if (raw.includes("<") && raw.includes(">")) return raw;
  if (raw.includes("@")) return `ERP Mobile <${raw}>`;
  return raw;
}

export async function sendResendEmail(
  payload: {
    to: string[];
    subject: string;
    text: string;
    cc?: string[];
  },
): Promise<{ ok: boolean; error?: string }> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    return { ok: false, error: "RESEND_API_KEY lipsește din Edge Functions." };
  }

  const body: Record<string, unknown> = {
    from: getEmailFromAddress(),
    to: payload.to,
    subject: payload.subject,
    text: payload.text,
  };
  if (payload.cc?.length) {
    body.cc = payload.cc;
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const text = await response.text();
    return { ok: false, error: `Resend (${response.status}): ${text}` };
  }

  return { ok: true };
}
