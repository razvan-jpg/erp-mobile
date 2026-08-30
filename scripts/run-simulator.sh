#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="ERP Mobile"
BUNDLE_ID="ro.dateconta.ERP-Mobile"
DERIVED_DATA="${ROOT_DIR}/DerivedData"
APP_PATH="${DERIVED_DATA}/Build/Products/Debug-iphonesimulator/ERPMobile.app"

echo "========================================"
echo "  ERP Mobile — Lansare Simulator"
echo "========================================"

is_simulator_binary() {
  local binary="$1"
  [[ -f "${binary}" ]] || return 1
  otool -l "${binary}" 2>/dev/null | awk '/platform/ {print $2; exit}' | grep -q '^7$'
}

# Oprește procesele blocate ale simulatorului
killall -9 Simulator 2>/dev/null || true
xcrun simctl shutdown all 2>/dev/null || true

# Alege primul simulator iOS disponibil (preferă iPhone)
SIM_ID="$(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
devices = []
for runtime, list_ in data.get('devices', {}).items():
    if 'iOS' not in runtime:
        continue
    for d in list_:
        if d.get('isAvailable'):
            devices.append(d)
devices.sort(key=lambda d: (0 if 'iPhone' in d['name'] else 1, d['name']))
print(devices[0]['udid'] if devices else '')
")"

if [[ -z "${SIM_ID}" ]]; then
  echo "Eroare: niciun simulator iOS disponibil."
  exit 1
fi

SIM_NAME="$(xcrun simctl list devices | grep "${SIM_ID}" | sed -E 's/^[[:space:]]*//; s/ \\(.*//')"
echo "Simulator: ${SIM_NAME}"

echo "[1/5] Clean build pentru simulator..."
xcodebuild \
  -project "${ROOT_DIR}/ERP Mobile.xcodeproj" \
  -scheme "${SCHEME}" \
  -destination "platform=iOS Simulator,id=${SIM_ID}" \
  -derivedDataPath "${DERIVED_DATA}" \
  clean build \
  | tail -8

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Eroare: aplicația nu a fost găsită la ${APP_PATH}"
  exit 1
fi

if ! is_simulator_binary "${APP_PATH}/ERPMobile"; then
  echo "Eroare: build-ul nu este pentru simulator (Debug-iphonesimulator)."
  echo "Verifică în Xcode că destinația este un simulator, nu „Any iOS Device”."
  exit 1
fi

echo "[2/6] Pornire simulator..."
xcrun simctl boot "${SIM_ID}" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "${SIM_ID}" -b 2>/dev/null || sleep 3

echo "[3/6] Dezinstalare versiune veche..."
xcrun simctl uninstall "${SIM_ID}" "${BUNDLE_ID}" 2>/dev/null || true

echo "[4/6] Instalare aplicație simulator..."
xcrun simctl install "${SIM_ID}" "${APP_PATH}"

echo "[5/6] Așteptare SpringBoard..."
sleep 2

echo "[6/6] Lansare aplicație..."
if ! PID="$(xcrun simctl launch "${SIM_ID}" "${BUNDLE_ID}" 2>&1)"; then
  echo "Eroare la lansare: ${PID}"
  exit 1
fi
echo "Aplicația rulează (pid: ${PID})."
echo ""
echo "Dacă Xcode tot dă „preflight checks”:"
echo "  1. Destinație: un simulator iOS (ex. iPad Pro / iPhone 17), NU „Any iOS Device”"
echo "  2. Product → Clean Build Folder (⇧⌘K), apoi Rulează din nou"
echo "  3. Simulator → Device → Erase All Content and Settings"
echo "  4. Rulează FIX-SIMULATOR-PREFLIGHT.command din folderul proiectului"
echo "  5. Opțional: pune proiectul în afara Dropbox (calea cu spații poate bloca lansarea)"
