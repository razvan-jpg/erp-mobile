#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="ERP Mobile"
BUNDLE_ID="ro.dateconta.ERP-Mobile"
BUILD_ROOT="${ROOT_DIR}/build/mac-installer"
DERIVED_DATA="${BUILD_ROOT}/DerivedData"
DIST_DIR="${ROOT_DIR}/dist"
PLIST_PATH="${ROOT_DIR}/ERP Mobile/Config/SupabaseSecrets.plist"
SECRETS_XCCONFIG="${ROOT_DIR}/Secrets.xcconfig"
EXPORT_MODE="development"

usage() {
  cat <<'EOF'
Utilizare: build-mac-installer.sh [--developer-id]

  (implicit)       Build semnat Development + DMG + PKG pentru test pe alte Mac-uri din echipă.
  --developer-id   Export Developer ID + notarizare (necesită certificat + APPLE_ID / APPLE_APP_PASSWORD).

Rezultat: dist/ERP-Mobile-<versiune>-Mac.dmg și .pkg
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --developer-id)
      EXPORT_MODE="developer-id"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Opțiune necunoscută: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

resolve_xcode_developer_dir() {
  if [[ -n "${DEVELOPER_DIR:-}" && -x "${DEVELOPER_DIR}/usr/bin/xcodebuild" ]]; then
    printf '%s' "${DEVELOPER_DIR}"
    return 0
  fi

  local selected=""
  selected="$(xcode-select -p 2>/dev/null || true)"
  if [[ -n "${selected}" && -x "${selected}/usr/bin/xcodebuild" ]]; then
    if "${selected}/usr/bin/xcodebuild" -version >/dev/null 2>&1; then
      printf '%s' "${selected}"
      return 0
    fi
  fi

  local candidate app
  for app in /Applications/Xcode.app /Applications/Xcode-beta.app; do
    candidate="${app}/Contents/Developer"
    if [[ -x "${candidate}/usr/bin/xcodebuild" ]]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done

  while IFS= read -r app; do
    [[ -z "${app}" ]] && continue
    candidate="${app}/Contents/Developer"
    if [[ -x "${candidate}/usr/bin/xcodebuild" ]]; then
      printf '%s' "${candidate}"
      return 0
    fi
  done < <(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null | head -n 5)

  return 1
}

echo "========================================"
echo "  ERP Mobile — Installer Mac (Catalyst)"
echo "========================================"

if ! DEVELOPER_DIR="$(resolve_xcode_developer_dir)"; then
  echo ""
  echo "Eroare: Xcode nu este configurat."
  echo "Instalează Xcode, apoi rulează:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo ""
  echo "Sau setează manual calea către Xcode-beta:"
  echo "  export DEVELOPER_DIR=\"/cale/către/Xcode.app/Contents/Developer\""
  exit 1
fi

export DEVELOPER_DIR
echo "Xcode: $("${DEVELOPER_DIR}/usr/bin/xcodebuild" -version | head -n 1)"
echo "Developer dir: ${DEVELOPER_DIR}"

if [[ ! -f "${SECRETS_XCCONFIG}" ]]; then
  echo ""
  echo "Eroare: lipsește Secrets.xcconfig"
  echo "Rulează mai întâi SETUP-SUPABASE.command din folderul proiectului."
  exit 1
fi

if [[ ! -f "${PLIST_PATH}" ]]; then
  echo ""
  echo "Eroare: lipsește ERP Mobile/Config/SupabaseSecrets.plist"
  echo "Rulează SETUP-SUPABASE.command sau copiază SupabaseSecrets.plist.example și completează valorile."
  exit 1
fi

MARKETING_VERSION="$(grep -m1 'MARKETING_VERSION = ' "${ROOT_DIR}/ERP Mobile.xcodeproj/project.pbxproj" | sed -E 's/.*MARKETING_VERSION = ([^;]+);/\1/' | tr -d '[:space:]')"
BUILD_NUMBER="$(sed -n 's/.*"buildNumber"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "${ROOT_DIR}/Supporting/VersionBuildState.json" 2>/dev/null | head -n 1)"
BUILD_NUMBER="${BUILD_NUMBER:-0}"
VERSION_LABEL="v${MARKETING_VERSION}-b${BUILD_NUMBER}"
DMG_NAME="ERP-Mobile-${VERSION_LABEL}-Mac.dmg"
PKG_NAME="ERP-Mobile-${VERSION_LABEL}-Mac.pkg"
DISPLAY_APP_NAME="ERP Mobile.app"

mkdir -p "${DIST_DIR}" "${BUILD_ROOT}"

find_built_app() {
  find "${DERIVED_DATA}/Build/Products" -maxdepth 2 -name "*.app" -type d 2>/dev/null | head -n 1
}

find_app_entitlements() {
  find "${DERIVED_DATA}/Build/Intermediates.noindex" -name 'ERPMobile.app.xcent' 2>/dev/null | head -n 1
}

sign_built_app() {
  local app_path="$1"
  local entitlements
  local sign_identity
  local sign_workspace
  local signed_app

  sign_identity="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/{print $2; exit}')"
  if [[ -z "${sign_identity}" ]]; then
    echo "Eroare: nu am găsit certificat Apple Development în Keychain." >&2
    exit 1
  fi

  sign_workspace="$(mktemp -d /tmp/erp-mobile-sign.XXXXXX)"
  signed_app="${sign_workspace}/ERP Mobile.app"

  echo "" >&2
  echo "[+] Copiere aplicație în afara Dropbox pentru semnare..." >&2
  ditto --norsrc "${app_path}" "${signed_app}"

  echo "[+] Curățare atribute extended (Dropbox/iCloud)..." >&2
  xattr -cr "${signed_app}"
  find "${signed_app}" -name '._*' -delete 2>/dev/null || true
  find "${signed_app}" -name '.DS_Store' -delete 2>/dev/null || true
  dot_clean -m "${signed_app}" 2>/dev/null || true

  entitlements="$(find_app_entitlements)"
  if [[ -n "${entitlements}" ]]; then
    echo "[+] Semnare: ${sign_identity}" >&2
    codesign --force --sign "${sign_identity}" --entitlements "${entitlements}" -o runtime "${signed_app}"
  else
    echo "[+] Semnare (fără entitlements generate): ${sign_identity}" >&2
    codesign --force --sign "${sign_identity}" -o runtime "${signed_app}"
  fi

  if ! codesign --verify --deep --strict "${signed_app}" >/dev/null 2>&1; then
    echo "Eroare: semnarea aplicației a eșuat." >&2
    exit 1
  fi

  rm -rf "${app_path}"
  ditto --norsrc "${signed_app}" "${app_path}"
  xattr -cr "${app_path}"
  rm -rf "${sign_workspace}"
}

build_release_app() {
  echo "" >&2
  echo "[1/4] Build Release (Mac Catalyst)..." >&2
  export COPYFILE_DISABLE=1
  set +e
  xcodebuild \
    -project "${ROOT_DIR}/ERP Mobile.xcodeproj" \
    -scheme "${SCHEME}" \
    -destination 'platform=macOS,variant=Mac Catalyst' \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA}" \
    CODE_SIGNING_ALLOWED=NO \
    clean build \
    2>&1 | tee "${BUILD_ROOT}/xcodebuild.log" \
    | grep -E '^(Build|Compile|CodeSign|Validate|Touch|note:|warning:|error:|\*\*)' >&2
  local build_status=${PIPESTATUS[0]}
  set -e

  local app_path
  app_path="$(find_built_app)"
  if [[ ${build_status} -ne 0 ]]; then
    echo "" >&2
    echo "Eroare: build-ul Xcode a eșuat (cod ${build_status})." >&2
    echo "Verifică logul: ${BUILD_ROOT}/xcodebuild.log" >&2
    exit 1
  fi
  if [[ -z "${app_path}" || ! -d "${app_path}" ]]; then
    echo "" >&2
    echo "Eroare: aplicația nu a fost găsită după build." >&2
    echo "Verifică logul: ${BUILD_ROOT}/xcodebuild.log" >&2
    exit 1
  fi

  sign_built_app "${app_path}"
  printf '%s' "${app_path}"
}

archive_and_export_app() {
  local archive_path="${BUILD_ROOT}/ERPMobile.xcarchive"
  local export_path="${BUILD_ROOT}/export"
  local export_plist="${BUILD_ROOT}/ExportOptions.plist"

  rm -rf "${archive_path}" "${export_path}"
  mkdir -p "${export_path}"

  cat > "${export_plist}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>teamID</key>
  <string>GN5Y8CBBC8</string>
  <key>signingStyle</key>
  <string>automatic</string>
</dict>
</plist>
EOF

  echo "" >&2
  echo "[1/5] Archive Release (Mac Catalyst)..." >&2
  xcodebuild archive \
    -project "${ROOT_DIR}/ERP Mobile.xcodeproj" \
    -scheme "${SCHEME}" \
    -destination 'generic/platform=macOS,variant=Mac Catalyst' \
    -archivePath "${archive_path}" \
    -configuration Release \
    2>&1 | tee "${BUILD_ROOT}/xcodebuild-archive.log" \
    | grep -E '^(Archive|CodeSign|Validate|note:|warning:|error:|\*\*)' >&2 || true

  echo "" >&2
  echo "[2/5] Export Developer ID..." >&2
  xcodebuild -exportArchive \
    -archivePath "${archive_path}" \
    -exportPath "${export_path}" \
    -exportOptionsPlist "${export_plist}" \
    2>&1 | tee "${BUILD_ROOT}/xcodebuild-export.log" \
    | grep -E '^(Export|CodeSign|note:|warning:|error:|\*\*)' >&2 || true

  local app_path="${export_path}/${DISPLAY_APP_NAME}"
  if [[ ! -d "${app_path}" ]]; then
    app_path="$(find "${export_path}" -maxdepth 1 -name '*.app' -type d | head -n 1)"
  fi
  if [[ -z "${app_path}" || ! -d "${app_path}" ]]; then
    echo ""
    echo "Eroare: export Developer ID eșuat."
    echo "Verifică certificatul „Developer ID Application” în Keychain / Xcode → Signing."
    exit 1
  fi
  printf '%s' "${app_path}"
}

notarize_pkg_if_possible() {
  local pkg_path="$1"
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
    echo ""
    echo "Notă: omit notarizarea (setează APPLE_ID și APPLE_APP_PASSWORD pentru instalare fără avertismente Gatekeeper)."
    return 0
  fi

  echo ""
  echo "[+] Notarizare Apple..."
  xcrun notarytool submit "${pkg_path}" \
    --apple-id "${APPLE_ID}" \
    --password "${APPLE_APP_PASSWORD}" \
    --team-id GN5Y8CBBC8 \
    --wait

  xcrun stapler staple "${pkg_path}"
  echo "PKG notarizat și stapled."
}

write_install_notes() {
  local target_dir="$1"
  cat > "${target_dir}/Cum instalez.txt" <<EOF
ERP Mobile ${MARKETING_VERSION} (build ${BUILD_NUMBER}) — instalare pe Mac

IMPORTANT: folosiți DOAR fișierul .dmg (NU .pkg — macOS îl blochează la build de test).

Pași
1. Copiați ${DMG_NAME} pe celălalt Mac (AirDrop, USB, etc.)
2. Dacă macOS refuză deschiderea DMG-ului, rulați în Terminal:
   xattr -dr com.apple.quarantine ~/Downloads/${DMG_NAME}
   open ~/Downloads/${DMG_NAME}
3. Trageți „ERP Mobile” peste folderul Applications
4. Prima deschidere a aplicației:
   - click dreapta pe ERP Mobile → Deschide → Deschide din nou
   SAU System Settings → Privacy & Security → Open Anyway
   SAU în Terminal:
   xattr -dr com.apple.quarantine "/Applications/ERP Mobile.app"
   open "/Applications/ERP Mobile.app"

Cont și date
- Același cont ERP ca pe App Store (date în Supabase).

Actualizare
- Ștergeți versiunea veche din Applications, apoi instalați noul DMG.

Versiune: ${VERSION_LABEL}
EOF
}

stage_app_for_distribution() {
  local source_app="$1"
  local staging_dir="${BUILD_ROOT}/staging"
  rm -rf "${staging_dir}"
  mkdir -p "${staging_dir}"

  echo "" >&2
  echo "[2/4] Pregătire pachet instalare..." >&2
  ditto --norsrc "${source_app}" "${staging_dir}/${DISPLAY_APP_NAME}"
  ln -s /Applications "${staging_dir}/Applications"
  write_install_notes "${staging_dir}"
  printf '%s' "${staging_dir}"
}

create_dmg() {
  local staging_dir="$1"
  local dmg_path="${DIST_DIR}/${DMG_NAME}"
  echo "" >&2
  echo "[3/4] Creare DMG..." >&2
  rm -f "${dmg_path}"
  hdiutil create \
    -volname "ERP Mobile ${MARKETING_VERSION}" \
    -srcfolder "${staging_dir}" \
    -ov \
    -format UDZO \
    "${dmg_path}" >/dev/null
  echo "DMG: ${dmg_path}" >&2
}

create_pkg() {
  local source_app="$1"
  local pkg_path="${DIST_DIR}/${PKG_NAME}"
  echo "" >&2
  echo "[4/4] Creare PKG..." >&2
  rm -f "${pkg_path}"
  pkgbuild \
    --component "${source_app}" \
    --install-location /Applications \
    --identifier "${BUNDLE_ID}.installer" \
    --version "${MARKETING_VERSION}.${BUILD_NUMBER}" \
    "${pkg_path}" >/dev/null
  echo "PKG: ${pkg_path}" >&2
}

write_install_helper() {
  cat > "${DIST_DIR}/INSTALARE-PE-ALT-MAC.command" <<EOF
#!/bin/bash
# Rulează pe Mac-ul unde instalezi ERP Mobile (nu pe Mac-ul de build).
# Versiune: ${VERSION_LABEL}

set -euo pipefail

DMG_NAME="${DMG_NAME}"
DMG_PATH="\${HOME}/Downloads/\${DMG_NAME}"
APP_PATH="/Applications/ERP Mobile.app"

echo "========================================"
echo "  ERP Mobile ${VERSION_LABEL} — instalare"
echo "========================================"

if [[ ! -f "\${DMG_PATH}" ]]; then
  echo ""
  echo "Nu găsesc: \${DMG_PATH}"
  echo "Copiază \${DMG_NAME} în folderul Downloads, apoi rulează din nou."
  read -r -p "Apasă Enter pentru a închide..."
  exit 1
fi

echo ""
echo "[1/3] Eliminare blocaj Gatekeeper de pe DMG..."
xattr -dr com.apple.quarantine "\${DMG_PATH}" 2>/dev/null || true

echo "[2/3] Deschidere DMG..."
open "\${DMG_PATH}"
echo ""
echo "Trage „ERP Mobile” în folderul Applications din fereastra deschisă."
read -r -p "Apasă Enter după ce ai copiat aplicația în Applications..."

if [[ -d "\${APP_PATH}" ]]; then
  echo ""
  echo "[3/3] Eliminare blocaj de pe aplicație..."
  xattr -dr com.apple.quarantine "\${APP_PATH}" 2>/dev/null || true
  echo "Deschidere ERP Mobile..."
  open "\${APP_PATH}" || true
  echo ""
  echo "Dacă tot nu se deschide: click dreapta pe ERP Mobile → Deschide → Deschide."
else
  echo ""
  echo "Nu am găsit \${APP_PATH} — verifică că ai tras aplicația în Applications."
fi

echo ""
read -r -p "Apasă Enter pentru a închide..."
EOF
  chmod +x "${DIST_DIR}/INSTALARE-PE-ALT-MAC.command"
}

APP_PATH=""
if [[ "${EXPORT_MODE}" == "developer-id" ]]; then
  APP_PATH="$(archive_and_export_app)"
  STAGING_DIR="$(stage_app_for_distribution "${APP_PATH}")"
  create_dmg "${STAGING_DIR}"
  create_pkg "${APP_PATH}"
  notarize_pkg_if_possible "${DIST_DIR}/${PKG_NAME}"
else
  APP_PATH="$(build_release_app)"
  STAGING_DIR="$(stage_app_for_distribution "${APP_PATH}")"
  create_dmg "${STAGING_DIR}"
  echo "" >&2
  echo "Notă: build Development generează doar DMG (PKG-ul nesemnat este blocat de macOS)." >&2
fi

write_install_helper

echo ""
echo "========================================"
echo "  Gata — copiază pe celălalt Mac:"
echo "  ${DIST_DIR}/${DMG_NAME}"
if [[ "${EXPORT_MODE}" == "developer-id" ]]; then
  echo "  ${DIST_DIR}/${PKG_NAME}"
fi
echo "========================================"
echo ""
echo "Pe Mac-ul țintă: deschide DOAR DMG-ul (nu PKG), trage ERP Mobile în Applications."
echo "Dacă macOS blochează: Terminal → xattr -dr com.apple.quarantine ~/Downloads/${DMG_NAME}"
echo "Prima deschidere app: click dreapta → Deschide."
echo ""
if [[ "${EXPORT_MODE}" == "development" ]]; then
  echo "Pentru distribuție fără avertismente Gatekeeper:"
  echo "  ./scripts/build-mac-installer.sh --developer-id"
  echo "  (și opțional APPLE_ID + APPLE_APP_PASSWORD pentru notarizare)"
fi
