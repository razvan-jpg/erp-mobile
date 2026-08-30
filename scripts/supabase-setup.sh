#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPABASE_BIN="${ROOT_DIR}/.tools/supabase"
PROJECT_NAME="${SUPABASE_PROJECT_NAME:-ERP-Mobile-Dateconta}"
REGION="${SUPABASE_REGION:-eu-central-1}"
DB_PASSWORD="${SUPABASE_DB_PASSWORD:-}"

echo "========================================"
echo "  ERP Mobile — Setup Supabase"
echo "========================================"
echo ""

install_cli() {
  if [[ -x "${SUPABASE_BIN}" ]]; then
    return
  fi
  echo "[1/6] Instalez Supabase CLI..."
  mkdir -p "${ROOT_DIR}/.tools"
  ARCH="$(uname -m)"
  if [[ "${ARCH}" == "arm64" ]]; then
    TARBALL="supabase_darwin_arm64.tar.gz"
  else
    TARBALL="supabase_darwin_amd64.tar.gz"
  fi
  curl -fsSL -o "${ROOT_DIR}/.tools/supabase.tar.gz" \
    "https://github.com/supabase/cli/releases/download/v2.105.0/${TARBALL}"
  tar -xzf "${ROOT_DIR}/.tools/supabase.tar.gz" -C "${ROOT_DIR}/.tools"
  chmod +x "${SUPABASE_BIN}"
}

ensure_login() {
  if "${SUPABASE_BIN}" projects list >/dev/null 2>&1; then
    echo "[2/6] Autentificare Supabase: OK"
    return
  fi

  echo "[2/6] Autentificare Supabase"
  echo ""
  echo "  → Se deschide browserul."
  echo "  → Dacă nu ai cont, creează unul GRATUIT pe supabase.com."
  echo "  → Confirmă autentificarea în browser, apoi revino aici."
  echo ""
  "${SUPABASE_BIN}" login
}

generate_db_password() {
  if [[ -z "${DB_PASSWORD}" ]]; then
    DB_PASSWORD="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 24)"
  fi
  echo "${DB_PASSWORD}" > "${ROOT_DIR}/.supabase-db-password"
  chmod 600 "${ROOT_DIR}/.supabase-db-password"
}

create_or_link_project() {
  cd "${ROOT_DIR}"

  if [[ -f "${ROOT_DIR}/supabase/.temp/project-ref" ]]; then
    PROJECT_REF="$(cat "${ROOT_DIR}/supabase/.temp/project-ref")"
    echo "[3/6] Proiect existent legat: ${PROJECT_REF}"
    "${SUPABASE_BIN}" link --project-ref "${PROJECT_REF}" --password "${DB_PASSWORD}" --yes
    return
  fi

  echo "[3/6] Creez proiectul Supabase: ${PROJECT_NAME}"
  ORG_ID="$("${SUPABASE_BIN}" orgs list -o json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if d else '')")"
  if [[ -z "${ORG_ID}" ]]; then
    echo "Eroare: nu există organizație Supabase. Creează cont pe https://supabase.com"
    exit 1
  fi

  CREATE_JSON="$("${SUPABASE_BIN}" projects create "${PROJECT_NAME}" \
    --org-id "${ORG_ID}" \
    --db-password "${DB_PASSWORD}" \
    --region "${REGION}" \
    -o json)"

  PROJECT_REF="$(python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" <<< "${CREATE_JSON}")"
  echo "  Project Ref: ${PROJECT_REF}"
  echo "  Aștept inițializarea proiectului (~2 minute)..."
  sleep 120

  "${SUPABASE_BIN}" link --project-ref "${PROJECT_REF}" --password "${DB_PASSWORD}" --yes
}

run_migrations() {
  echo "[4/6] Rulez migrările bazei de date..."
  cd "${ROOT_DIR}"
  "${SUPABASE_BIN}" db push --yes
}

deploy_functions() {
  echo "[5/6] Deploy Edge Functions..."
  cd "${ROOT_DIR}"
  for fn in admin-create-user admin-update-user admin-toggle-block admin-delete-user admin-create-company admin-resend-confirmation update-own-password; do
    echo "  → ${fn}"
    "${SUPABASE_BIN}" functions deploy "${fn}" --yes
  done
  echo "  → seed-admin, email-confirmed, complete-account-activation, send-welcome-email (fără verificare JWT)"
  "${SUPABASE_BIN}" functions deploy seed-admin --no-verify-jwt --yes
  "${SUPABASE_BIN}" functions deploy email-confirmed --no-verify-jwt --yes
  "${SUPABASE_BIN}" functions deploy complete-account-activation --no-verify-jwt --yes
  "${SUPABASE_BIN}" functions deploy send-welcome-email --no-verify-jwt --yes
}

write_ios_config() {
  echo "[6/6] Configurez aplicația iOS..."
  PROJECT_REF="$(cat "${ROOT_DIR}/supabase/.temp/project-ref")"
  API_JSON="$("${SUPABASE_BIN}" projects api-keys --project-ref "${PROJECT_REF}" -o json)"
  ANON_KEY="$(python3 -c "import sys,json; keys=json.load(sys.stdin); print(next(k['api_key'] for k in keys if k['name']=='anon'))" <<< "${API_JSON}")"
  PROJECT_URL="https://${PROJECT_REF}.supabase.co"

  # xcconfig interpretează // ca comentariu — folosim https:/$()/ pentru URL
  ESCAPED_URL="https:/\$()/${PROJECT_REF}.supabase.co"

  cat > "${ROOT_DIR}/Secrets.xcconfig" <<EOF
// Generat automat de scripts/supabase-setup.sh
SUPABASE_URL = ${ESCAPED_URL}
SUPABASE_ANON_KEY = ${ANON_KEY}
#include "Supporting/GeneratedVersion.xcconfig"
EOF

  PLIST_PATH="${ROOT_DIR}/ERP Mobile/Config/SupabaseSecrets.plist"
  cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>SUPABASE_URL</key>
	<string>${PROJECT_URL}</string>
	<key>SUPABASE_ANON_KEY</key>
	<string>${ANON_KEY}</string>
</dict>
</plist>
EOF

  echo ""
  echo "========================================"
  echo "  Setup Supabase COMPLET"
  echo "========================================"
  echo "Project URL : ${PROJECT_URL}"
  echo "Project Ref : ${PROJECT_REF}"
  echo "Credențiale : Secrets.xcconfig"
  echo "Parolă DB   : .supabase-db-password"
  echo ""
  echo "Superadmin ERP (creat la primul launch):"
  echo "  Email  : razvan.ivan@icloud.com"
  echo "  Parolă : David12!"
  echo "  (nu poate fi șters; doar el creează societăți și alocă drepturi)"
  echo ""
  echo "Deschide ERP Mobile.xcodeproj și rulează aplicația."
}

install_cli
ensure_login
generate_db_password
create_or_link_project
run_migrations
deploy_functions
write_ios_config
