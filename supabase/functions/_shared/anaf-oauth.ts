import forge from "npm:node-forge@1.3.1";
import { getServiceClient } from "./admin.ts";

const AUTHORIZE_URL = "https://logincert.anaf.ro/anaf-oauth2/v1/authorize";
const REFRESH_MINUTES = 525600;
const INVITE_DAYS = 7;

export type OauthApp = {
  client_id: string;
  client_secret: string;
  redirect_uri: string;
};

export function supabaseBase(): string {
  return (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
}

export function redirectUri(): string {
  return `${supabaseBase()}/functions/v1/anaf-oauth-callback`;
}

export function inviteUrl(token: string): string {
  return `${supabaseBase()}/functions/v1/anaf-oauth-invite?token=${encodeURIComponent(token)}`;
}

export function inviteExpiry(from = new Date()): Date {
  return new Date(from.getTime() + INVITE_DAYS * 24 * 60 * 60 * 1000);
}

export async function loadOauthApp(): Promise<OauthApp | null> {
  const service = getServiceClient();
  const { data, error } = await service
    .from("anaf_oauth_app")
    .select("client_id, client_secret, redirect_uri")
    .eq("id", 1)
    .maybeSingle();
  if (error || !data?.client_id || !data?.client_secret) return null;
  return data as OauthApp;
}

export function authorizeUrl(app: OauthApp, state: string): string {
  const params = new URLSearchParams({
    response_type: "code",
    client_id: app.client_id,
    redirect_uri: app.redirect_uri,
    token_content_type: "jwt",
    state,
  });
  return `${AUTHORIZE_URL}?${params.toString()}`;
}

export async function exchangeAuthorizationCode(
  app: OauthApp,
  code: string,
): Promise<{ accessToken: string; refreshToken: string; accessExpiresAt: Date; refreshExpiresAt: Date }> {
  return requestToken(app, new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: app.redirect_uri,
    token_content_type: "jwt",
  }));
}

async function requestToken(app: OauthApp, body: URLSearchParams) {
  const basic = btoa(`${app.client_id}:${app.client_secret}`);
  const response = await anafFormPost("/anaf-oauth2/v1/token", basic, body.toString());
  const payload = parseJson(response.body);
  if (response.status < 200 || response.status >= 300) {
    const description = typeof payload.error_description === "string"
      ? payload.error_description
      : typeof payload.error === "string"
      ? payload.error
      : `ANAF a răspuns ${response.status}`;
    throw new Error(description);
  }
  const accessToken = String(payload.access_token ?? "");
  const refreshToken = String(payload.refresh_token ?? "");
  if (!accessToken || !refreshToken) {
    throw new Error("ANAF nu a returnat tokenul de acces.");
  }
  const expiresIn = Number(payload.expires_in);
  const fromJwt = jwtExpiry(accessToken);
  const accessExpiresAt = fromJwt
    ?? (Number.isFinite(expiresIn) && expiresIn > 0
      ? new Date(Date.now() + expiresIn * 1000)
      : new Date(Date.now() + 90 * 24 * 60 * 60 * 1000));
  const refreshExpiresAt = new Date(Date.now() + REFRESH_MINUTES * 60 * 1000);
  return { accessToken, refreshToken, accessExpiresAt, refreshExpiresAt };
}

export async function refreshAccessToken(app: OauthApp, refreshToken: string) {
  return requestToken(app, new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: refreshToken,
    token_content_type: "jwt",
  }));
}

export async function revokeRefreshToken(app: OauthApp, refreshToken: string): Promise<void> {
  const basic = btoa(`${app.client_id}:${app.client_secret}`);
  await anafFormPost("/anaf-oauth2/v1/revoke", basic, new URLSearchParams({
    token: refreshToken,
    token_type_hint: "refresh_token",
  }).toString());
}

export async function anafFormPost(
  path: string,
  basic: string,
  form: string,
): Promise<{ status: number; body: string }> {
  const tcp = await Deno.connect({ hostname: "logincert.anaf.ro", port: 443 });
  const request = [
    `POST ${path} HTTP/1.1`,
    "Host: logincert.anaf.ro",
    `Authorization: Basic ${basic}`,
    "Content-Type: application/x-www-form-urlencoded",
    "Accept: application/json",
    "User-Agent: ERPMobile",
    `Content-Length: ${new TextEncoder().encode(form).length}`,
    "Connection: close",
    "",
    form,
  ].join("\r\n");

  let appData = "";
  let failed: Error | null = null;
  const client = forge.tls.createConnection({
    server: false,
    virtualHost: "logincert.anaf.ro",
    cipherSuites: [
      forge.tls.CipherSuites.TLS_RSA_WITH_AES_128_CBC_SHA,
      forge.tls.CipherSuites.TLS_RSA_WITH_AES_256_CBC_SHA,
    ],
    verify: (_connection: unknown, _verified: boolean, depth: number, certs: Array<{
      subject: { getField: (name: string) => { value?: string } | null };
      validity: { notBefore: Date; notAfter: Date };
    }>) => {
      if (depth !== 0) return true;
      const cn = certs[0]?.subject.getField("CN")?.value ?? "";
      const now = new Date();
      const valid = certs[0].validity.notBefore <= now && certs[0].validity.notAfter >= now;
      return valid && (cn === "*.anaf.ro" || cn.endsWith(".anaf.ro"));
    },
    connected: (connection: { prepare: (data: string) => void }) => {
      connection.prepare(request);
    },
    tlsDataReady: (connection: { tlsData: { getBytes: () => string } }) => {
      const bytes = forge.util.binary.raw.decode(connection.tlsData.getBytes());
      tcp.write(bytes).catch((err) => {
        failed = err instanceof Error ? err : new Error(String(err));
      });
    },
    dataReady: (connection: { data: { getBytes: () => string } }) => {
      appData += connection.data.getBytes();
    },
    closed: () => {},
    error: (_connection: unknown, error: { message?: string }) => {
      failed = new Error(error?.message ?? "Conexiunea cu ANAF a eșuat.");
    },
  });

  const timer = setTimeout(() => {
    failed = new Error("ANAF nu a răspuns la timp.");
    try { tcp.close(); } catch { /* already closed */ }
  }, 20000);

  try {
    client.handshake();
    const buf = new Uint8Array(16384);
    while (failed === null) {
      const read = await tcp.read(buf);
      if (read === null) break;
      client.process(forge.util.binary.raw.encode(buf.subarray(0, read)));
    }
  } finally {
    clearTimeout(timer);
    try { tcp.close(); } catch { /* already closed */ }
  }
  if (failed) throw failed;

  const breakAt = appData.indexOf("\r\n\r\n");
  const head = breakAt >= 0 ? appData.slice(0, breakAt) : appData;
  let body = breakAt >= 0 ? appData.slice(breakAt + 4) : "";
  const status = Number((head.match(/HTTP\/\d(?:\.\d)? (\d+)/) ?? [])[1] ?? 0);
  if (/transfer-encoding:\s*chunked/i.test(head)) body = decodeChunked(body);
  return { status, body };
}

export function bucharestDay(date: Date): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Bucharest",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

export function htmlPage(title: string, message: string): Response {
  const safeTitle = escapeHtml(title);
  const safeMessage = escapeHtml(message);
  const html = `<!DOCTYPE html>
<html lang="ro">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${safeTitle}</title>
  <style>
    body { font-family: -apple-system, Segoe UI, sans-serif; background: #f4f7fb; color: #10233f; margin: 0; }
    main { max-width: 32rem; margin: 4rem auto; background: white; padding: 2rem; border-radius: 12px; }
    h1 { font-size: 1.4rem; margin: 0 0 1rem; }
    p { line-height: 1.5; margin: 0; }
  </style>
</head>
<body><main><h1>${safeTitle}</h1><p>${safeMessage}</p></main></body>
</html>`;
  return new Response(html, {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

function jwtExpiry(token: string): Date | null {
  const part = token.split(".")[1];
  if (!part) return null;
  try {
    const base64 = part.replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4);
    const json = JSON.parse(atob(padded));
    if (typeof json.exp === "number") return new Date(json.exp * 1000);
  } catch {
    return null;
  }
  return null;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replace(/[^\x00-\x7F]/g, (char) => `&#${char.codePointAt(0)};`);
}

function parseJson(body: string): Record<string, unknown> {
  try {
    return JSON.parse(body) as Record<string, unknown>;
  } catch {
    return {};
  }
}

function concatBytes(chunks: Uint8Array[]): Uint8Array {
  const size = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  const out = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    out.set(chunk, offset);
    offset += chunk.length;
  }
  return out;
}

function decodeChunked(body: string): string {
  let rest = body;
  let out = "";
  while (rest.length > 0) {
    const lineEnd = rest.indexOf("\r\n");
    if (lineEnd < 0) break;
    const size = Number.parseInt(rest.slice(0, lineEnd), 16);
    if (!Number.isFinite(size) || size === 0) break;
    const start = lineEnd + 2;
    out += rest.slice(start, start + size);
    rest = rest.slice(start + size + 2);
  }
  return out;
}
