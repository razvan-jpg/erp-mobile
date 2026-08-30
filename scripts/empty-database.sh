#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPABASE_BIN="${ROOT_DIR}/.tools/supabase"
SQL_FILE="${ROOT_DIR}/scripts/empty-database.sql"

echo "========================================"
echo "  ERP Mobile — Golire bază de date"
echo "========================================"
echo ""
echo "Această operație șterge TOATE datele:"
echo "  - furnizori, facturi, plăți"
echo "  - utilizatori, permisiuni"
echo "  - conturi auth"
echo "  (fișierele statice din Storage nu sunt șterse)"
echo ""
echo "Schema, migrările și funcțiile rămân intacte."
echo "Catalogul de module este reîncărcat."
echo "Adminul implicit se recreează la primul launch al aplicației."
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
echo "Baza de date a fost golită."
echo "Deschide aplicația pentru a recrea superadmin razvan.ivan@icloud.com (parolă: David12!)."
