#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPABASE_BIN="${ROOT_DIR}/.tools/supabase-go"
if [[ ! -x "${SUPABASE_BIN}" ]]; then
  SUPABASE_BIN="${ROOT_DIR}/.tools/supabase"
fi

echo "========================================"
echo "  ERP Mobile — Configurare Resend"
echo "========================================"
echo ""

if [[ ! -x "${SUPABASE_BIN}" ]]; then
  echo "Supabase CLI lipsește. Rulează mai întâi SETUP-SUPABASE.command"
  exit 1
fi

if ! "${SUPABASE_BIN}" projects list >/dev/null 2>&1; then
  echo "Nu ești autentificat la Supabase. Rulează:"
  echo "  ${SUPABASE_BIN} login"
  exit 1
fi

PROJECT_REF=""
if [[ -f "${ROOT_DIR}/supabase/.temp/project-ref" ]]; then
  PROJECT_REF="$(cat "${ROOT_DIR}/supabase/.temp/project-ref")"
fi

echo "Pași în Resend (https://resend.com):"
echo "  1. Cont → API Keys → cheie cu permisiune Sending (sau Full Access pentru automatizare domenii)"
echo "  2. Domains → Add domain → dateconta.ro → copiază recordurile DNS"
echo "  3. cPanel → Zone Editor (dateconta.ro) → adaugă TXT/CNAME/MX afișate de Resend → Verify"
echo ""
if [[ -n "${PROJECT_REF}" ]]; then
  echo "Proiect Supabase: ${PROJECT_REF}"
  echo "Dashboard secrets: https://supabase.com/dashboard/project/${PROJECT_REF}/settings/functions"
fi
echo ""

echo "Secretelor curente în Supabase:"
"${SUPABASE_BIN}" secrets list 2>/dev/null | grep -E "RESEND|EMAIL_" || true
echo ""

read -r -p "Resend API Key (re_...): " RESEND_API_KEY
if [[ -z "${RESEND_API_KEY}" ]]; then
  echo "API key lipsă — ieșire."
  exit 1
fi

read -r -p "EMAIL_FROM [ERP Mobile <ERPMobile@dateconta.ro>]: " EMAIL_FROM
EMAIL_FROM="${EMAIL_FROM:-ERP Mobile <ERPMobile@dateconta.ro>}"

DEFAULT_REDIRECT="https://rincon.ro/email-confirmat.html"

if [[ -n "${DEFAULT_REDIRECT}" ]]; then
  read -r -p "EMAIL_CONFIRM_REDIRECT_URL [${DEFAULT_REDIRECT}]: " EMAIL_CONFIRM_REDIRECT_URL
  EMAIL_CONFIRM_REDIRECT_URL="${EMAIL_CONFIRM_REDIRECT_URL:-${DEFAULT_REDIRECT}}"
else
  read -r -p "EMAIL_CONFIRM_REDIRECT_URL (opțional): " EMAIL_CONFIRM_REDIRECT_URL
fi

read -r -p "ACTIVATION_EMAIL_CC [ERPMobile@dateconta.ro]: " ACTIVATION_EMAIL_CC
ACTIVATION_EMAIL_CC="${ACTIVATION_EMAIL_CC:-ERPMobile@dateconta.ro}"

echo ""
echo "Setez secretele în Supabase Edge Functions..."

SECRET_ARGS=(
  "RESEND_API_KEY=${RESEND_API_KEY}"
  "EMAIL_FROM=${EMAIL_FROM}"
  "EMAIL_CONFIRM_REDIRECT_URL=${EMAIL_CONFIRM_REDIRECT_URL}"
  "ACTIVATION_EMAIL_CC=${ACTIVATION_EMAIL_CC}"
)

"${SUPABASE_BIN}" secrets set "${SECRET_ARGS[@]}"

echo ""
echo "========================================"
echo "  Resend configurat în Supabase"
echo "========================================"
echo ""
echo "Verifică și în Supabase Dashboard:"
echo "  Authentication → Providers → Email → Confirm email = ON"
if [[ -n "${EMAIL_CONFIRM_REDIRECT_URL}" ]]; then
  echo "  Authentication → URL Configuration → Redirect URLs → adaugă:"
  echo "    ${EMAIL_CONFIRM_REDIRECT_URL}"
fi
echo ""
echo "Flux email:"
echo "  1. Utilizatorul primește link de confirmare"
echo "  2. După click → pagină „Cont confirmat cu succes”"
echo "  3. Utilizatorul primește email cu date cont (CC: ${ACTIVATION_EMAIL_CC:-ERPMobile@dateconta.ro})"
echo ""
echo "Test:"
echo "  1. Creează un utilizator nou din app (Admin → Utilizatori)"
echo "  2. Confirmă emailul din link"
echo "  3. Verifică pagina de succes și emailul cu date cont"
echo ""
echo "Dacă emailurile nu sosesc:"
echo "  - Domeniul din EMAIL_FROM trebuie verificat în Resend → Domains"
echo "  - Cu onboarding@resend.dev poți trimite doar către emailul contului Resend"
echo "  - Verifică spam / Logs în Resend Dashboard → Emails"
echo ""
