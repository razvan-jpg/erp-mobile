#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="ro.dateconta.ERP-Mobile"
DERIVED_DATA="${ROOT_DIR}/DerivedData"
XCODE_DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"

echo "========================================"
echo "  ERP Mobile — Remediere preflight"
echo "========================================"

echo "[1/7] Oprire Simulator și servicii blocate..."
killall -9 Simulator 2>/dev/null || true
xcrun simctl shutdown all 2>/dev/null || true
killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
sleep 2

echo "[2/7] Ștergere aplicație din toate simulatoarele..."
while IFS= read -r sim_id; do
  xcrun simctl uninstall "${sim_id}" "${BUNDLE_ID}" 2>/dev/null || true
done < <(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if d.get('isAvailable'):
            print(d['udid'])
")

echo "[3/7] Curățare DerivedData local..."
rm -rf "${DERIVED_DATA}"

echo "[4/7] Curățare DerivedData Xcode pentru acest proiect..."
rm -rf "${XCODE_DERIVED_DATA}"/ERP_Mobile-* 2>/dev/null || true

echo "[5/7] Clean build folder în Xcode..."
xcodebuild \
  -project "${ROOT_DIR}/ERP Mobile.xcodeproj" \
  -scheme "ERP Mobile" \
  -derivedDataPath "${DERIVED_DATA}" \
  clean 2>/dev/null || true

echo "[6/7] Rebuild + lansare simulator..."
"${ROOT_DIR}/scripts/run-simulator.sh"

echo "[7/7] Gata."
echo ""
echo "Acum în Xcode:"
echo "  • Alege destinația: iPad Pro 13-inch (M5) sau iPhone 17 (simulator)"
echo "  • NU folosi „Any iOS Device” sau „My Mac”"
echo "  • Product → Clean Build Folder (⇧⌘K), apoi ▶ Run"
