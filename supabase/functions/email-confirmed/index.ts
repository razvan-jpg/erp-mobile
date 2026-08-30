import { handleCors } from "../_shared/cors.ts";
import { getEmailConfirmRedirectUrl } from "../_shared/redirect-url.ts";

/**
 * Supabase Edge Functions nu pot servi HTML (forțează text/plain).
 * Această funcție redirecționează către pagina statică reală, păstrând tokenii din URL.
 */
Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  const target = getEmailConfirmRedirectUrl();

  const incoming = new URL(req.url);
  const destination = new URL(target);

  incoming.searchParams.forEach((value, key) => {
    destination.searchParams.set(key, value);
  });

  const location = destination.toString() + incoming.hash;

  return new Response(null, {
    status: 302,
    headers: {
      Location: location,
      "Cache-Control": "no-store",
    },
  });
});
