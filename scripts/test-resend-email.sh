#!/usr/bin/env bash
# Testează trimiterea email prin Resend (necesită login Admin în app / credențiale)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPABASE_BIN="${ROOT_DIR}/.tools/supabase"
PLIST="${ROOT_DIR}/ERP Mobile/Config/SupabaseSecrets.plist"

if [[ ! -f "${PLIST}" ]]; then
  echo "Lipsește SupabaseSecrets.plist — rulează SETUP-SUPABASE.command"
  exit 1
fi

SUPABASE_URL=$(grep -A1 'SUPABASE_URL' "${PLIST}" | tail -1 | sed 's/.*<string>//;s/<\/string>//')
ANON_KEY=$(grep -A1 'SUPABASE_ANON_KEY' "${PLIST}" | tail -1 | sed 's/.*<string>//;s/<\/string>//')

read -r -p "Email Admin [razvan.ivan@icloud.com]: " ADMIN_EMAIL
ADMIN_EMAIL="${ADMIN_EMAIL:-razvan.ivan@icloud.com}"
read -r -s -p "Parolă Admin (aceeași ca în app ERP Mobile): " ADMIN_PASSWORD
echo ""

read -r -p "Destinatar test [ERPMobile@dateconta.ro]: " TEST_TO
TEST_TO="${TEST_TO:-ERPMobile@dateconta.ro}"

echo "Autentificare..."
AUTH_JSON=$(curl -sS -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\"}")

ACCESS_TOKEN=$(python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))" <<< "${AUTH_JSON}")

if [[ -z "${ACCESS_TOKEN}" ]]; then
  echo "Autentificare eșuată:"
  echo "${AUTH_JSON}" | python3 -m json.tool 2>/dev/null || echo "${AUTH_JSON}"
  echo ""
  echo "Folosește aceeași parolă cu care te loghezi în app (Superadmin)."
  echo "Dacă ai uitat-o, reseteaz-o din app sau din Supabase Dashboard → Authentication → Users."
  echo "Alternativ, testează doar Resend (fără login): bash scripts/test-resend-direct.sh"
  exit 1
fi

echo "Trimit email de test către ${TEST_TO}..."
RESULT=$(curl -sS -X POST "${SUPABASE_URL}/functions/v1/admin-test-email" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${TEST_TO}\"}")

echo "${RESULT}" | python3 -m json.tool 2>/dev/null || echo "${RESULT}"
