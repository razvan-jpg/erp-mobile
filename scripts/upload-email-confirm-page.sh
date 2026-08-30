#!/usr/bin/env bash
# Generează pagina HTML de confirmare pentru găzduire pe rincon.ro
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPABASE_BIN="${ROOT_DIR}/.tools/supabase"
PLIST="${ROOT_DIR}/ERP Mobile/Config/SupabaseSecrets.plist"
TEMPLATE="${ROOT_DIR}/web/email-confirmat.html"
OUT="${ROOT_DIR}/web/email-confirmat.built.html"
RINCON_URL="https://rincon.ro/email-confirmat.html"

if [[ ! -f "${PLIST}" ]]; then
  echo "Lipsește SupabaseSecrets.plist"
  exit 1
fi

SUPABASE_URL=$(grep -A1 'SUPABASE_URL' "${PLIST}" | tail -1 | sed 's/.*<string>//;s/<\/string>//')
ANON_KEY=$(grep -A1 'SUPABASE_ANON_KEY' "${PLIST}" | tail -1 | sed 's/.*<string>//;s/<\/string>//')

sed \
  -e "s|__SUPABASE_URL__|${SUPABASE_URL}|g" \
  -e "s|__SUPABASE_ANON_KEY__|${ANON_KEY}|g" \
  "${TEMPLATE}" > "${OUT}"

echo "========================================"
echo "  Pagină confirmare email — rincon.ro"
echo "========================================"
echo ""
echo "Fișier generat:"
echo "  ${OUT}"
echo ""
echo "IMPORTANT: Supabase NU poate afișa pagini HTML (doar text simplu)."
echo "Trebuie încărcat pe serverul web rincon.ro:"
echo ""
echo "  1. Conectați-vă la hosting-ul rincon.ro (FTP / cPanel / File Manager)"
echo "  2. Încărcați fișierul ca:  email-confirmat.html  (în rădăcina site-ului)"
echo "  3. Verificați în browser: ${RINCON_URL}"
echo "     → trebuie să vedeți o pagină frumoasă, NU cod HTML ca text"
echo ""

if [[ -x "${SUPABASE_BIN}" ]] && "${SUPABASE_BIN}" projects list >/dev/null 2>&1; then
  echo "Actualizez Supabase (redirect URL + Auth)..."
  "${SUPABASE_BIN}" secrets set "EMAIL_CONFIRM_REDIRECT_URL=${RINCON_URL}" 2>/dev/null || true
  "${SUPABASE_BIN}" config push --yes 2>/dev/null || true
  echo "✓ EMAIL_CONFIRM_REDIRECT_URL = ${RINCON_URL}"
fi

echo ""
echo "După upload pe rincon.ro, creați un utilizator nou și testați linkul de confirmare."
