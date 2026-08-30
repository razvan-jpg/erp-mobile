#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPABASE_BIN="${ROOT_DIR}/.tools/supabase"

MIGRATIONS=(
  "20250731000001_supplier_nir_lines_edit_permissions.sql"
  "20250731000002_fix_nir_line_reinsert_stock.sql"
  "20250731000003_fix_nir_invoice_delete_stock.sql"
  "20250731000004_supplier_nir_number_reuse.sql"
  "20250731000005_supplier_nir_lines_update_edit_permissions.sql"
)

echo "========================================"
echo "  ERP Mobile — Migrări NIR (edit save)"
echo "========================================"
echo ""
echo "Se aplică:"
for migration in "${MIGRATIONS[@]}"; do
  echo "  - ${migration}"
done
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

if "${SUPABASE_BIN}" db push --yes; then
  echo ""
  echo "Migrările au fost aplicate cu succes (db push)."
  exit 0
fi

echo ""
echo "db push a eșuat — încerc aplicarea fișierelor individual..."
for migration in "${MIGRATIONS[@]}"; do
  SQL_FILE="${ROOT_DIR}/supabase/migrations/${migration}"
  echo "→ ${migration}"
  "${SUPABASE_BIN}" db query --linked --file "${SQL_FILE}"
done

echo ""
echo "Migrările NIR au fost aplicate."
