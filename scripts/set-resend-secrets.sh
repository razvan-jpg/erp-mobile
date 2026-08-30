#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPABASE_BIN="${ROOT_DIR}/.tools/supabase-go"
if [[ ! -x "${SUPABASE_BIN}" ]]; then
  SUPABASE_BIN="${ROOT_DIR}/.tools/supabase"
fi
PROJECT_REF="${SUPABASE_PROJECT_REF:-uygkcpllczvpdtinjjih}"

EMAIL_FROM="${EMAIL_FROM:-ERP Mobile <ERPMobile@dateconta.ro>}"
ACTIVATION_EMAIL_CC="${ACTIVATION_EMAIL_CC:-ERPMobile@dateconta.ro}"
EMAIL_CONFIRM_REDIRECT_URL="${EMAIL_CONFIRM_REDIRECT_URL:-https://rincon.ro/email-confirmat.html}"

if [[ ! -x "${SUPABASE_BIN}" ]]; then
  echo "Supabase CLI lipsește. Rulează SETUP-SUPABASE.command"
  exit 1
fi

if [[ -z "${RESEND_API_KEY:-}" ]]; then
  echo "Setează RESEND_API_KEY înainte de rulare, ex.:"
  echo "  RESEND_API_KEY=re_abc123... bash scripts/set-resend-secrets.sh"
  exit 1
fi

if [[ "${RESEND_API_KEY}" == *"COPIAZA"* ]] || [[ "${RESEND_API_KEY}" == "re_..." ]] || [[ ${#RESEND_API_KEY} -lt 20 ]]; then
  echo "Cheia API pare invalidă (placeholder sau prea scurtă)."
  echo "Copiază cheia COMPLETĂ din Resend → API keys → Create API key."
  exit 1
fi

if ! "${SUPABASE_BIN}" projects list >/dev/null 2>&1; then
  echo "Nu ești autentificat la Supabase. Rulează: ${SUPABASE_BIN} login"
  exit 1
fi

echo "Setez secretele Resend pentru proiectul ${PROJECT_REF}..."
"${SUPABASE_BIN}" secrets set \
  --project-ref "${PROJECT_REF}" \
  "RESEND_API_KEY=${RESEND_API_KEY}" \
  "EMAIL_FROM=${EMAIL_FROM}" \
  "ACTIVATION_EMAIL_CC=${ACTIVATION_EMAIL_CC}" \
  "EMAIL_CONFIRM_REDIRECT_URL=${EMAIL_CONFIRM_REDIRECT_URL}"

echo ""
echo "Secrete configurate:"
echo "  EMAIL_FROM=${EMAIL_FROM}"
echo "  ACTIVATION_EMAIL_CC=${ACTIVATION_EMAIL_CC}"
echo "  EMAIL_CONFIRM_REDIRECT_URL=${EMAIL_CONFIRM_REDIRECT_URL}"
echo ""
echo "Verifică domeniul dateconta.ro în Resend → Domains (Verified)."
