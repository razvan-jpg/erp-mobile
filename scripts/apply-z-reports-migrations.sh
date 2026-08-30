#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -x "${ROOT_DIR}/.tools/supabase-go" ]]; then
  SUPABASE_BIN="${ROOT_DIR}/.tools/supabase-go"
elif [[ -x "${ROOT_DIR}/.tools/supabase" ]]; then
  SUPABASE_BIN="${ROOT_DIR}/.tools/supabase"
else
  SUPABASE_BIN="${ROOT_DIR}/.tools/supabase"
fi

echo "========================================"
echo "  ERP Mobile — Migrări Rapoarte Z"
echo "========================================"
echo ""
echo "Se aplică (db push):"
echo "  - 20250817000001_company_z_reports.sql"
echo "  - 20250817000002_company_z_report_collections.sql"
echo "  - 20250817000003_company_z_reports_client_rls.sql"
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

cd "${ROOT_DIR}"
"${SUPABASE_BIN}" db push --yes

echo ""
echo "Migrările Rapoarte Z au fost aplicate."
