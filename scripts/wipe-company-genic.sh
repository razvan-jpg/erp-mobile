#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPABASE_BIN="${ROOT_DIR}/.tools/supabase"
SQL_FILE="${ROOT_DIR}/scripts/wipe-company-genic.sql"

echo "========================================"
echo "  ERP Mobile — Golire date GENIC"
echo "========================================"
echo ""
echo "Această operație șterge datele operaționale pentru:"
echo "  GENIC TEAM INTERNATIONAL SRL"
echo ""
echo "Se șterg: furnizori, facturi, plăți, NIR, produse, stocuri,"
echo "          clienți, inventare, depozite, puncte de lucru."
echo ""
echo "Se PĂSTREAZĂ: înregistrarea societății, administratorul și drepturile."
echo ""

if [[ ! -x "${SUPABASE_BIN}" ]]; then
  echo "Eroare: Supabase CLI lipsește. Rulează SETUP-SUPABASE.command"
  exit 1
fi

if ! "${SUPABASE_BIN}" projects list >/dev/null 2>&1; then
  echo "Eroare: nu ești autentificat la Supabase. Rulează:"
  echo "  ${SUPABASE_BIN} login"
  exit 1
fi

read -r -p "Continui? (da/nu): " CONFIRM
if [[ "${CONFIRM}" != "da" ]]; then
  echo "Anulat."
  exit 0
fi

cd "${ROOT_DIR}"
"${SUPABASE_BIN}" db query --linked --file "${SQL_FILE}"

echo ""
echo "Datele operaționale pentru GENIC TEAM INTERNATIONAL SRL au fost golite."
