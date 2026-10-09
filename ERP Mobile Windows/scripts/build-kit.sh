#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
DOTNET="$REPO/.tools/dotnet/dotnet"
APP_PROJECT="$ROOT/src/ERPMobile/ERPMobile.csproj"
SETUP_PROJECT="$ROOT/Kit instalare/Sursa/ERPMobile.Setup.csproj"
BUILD="$ROOT/build"
PUBLISH="$BUILD/app"
PAYLOAD="/tmp/erp-mobile-windows-payload.zip"
SECRETS="$REPO/Secrets.xcconfig"
CONFIG="$PUBLISH/appconfig.json"
VERSION="$(sed -n 's/.*Version = "\([^"]*\)".*/\1/p' "$ROOT/src/ERPMobile/Ui/Brand.cs" | head -1)"
if [[ -z "$VERSION" ]]; then
  echo "Nu am găsit versiunea în Brand.cs." >&2
  exit 1
fi
KIT="$ROOT/Kit instalare/ERP Mobile Setup ${VERSION}.exe"

if [[ ! -x "$DOTNET" ]]; then
  echo "Lipsește .NET SDK în .tools/dotnet." >&2
  exit 1
fi

echo "ERP Mobile — kit Windows"
"$DOTNET" publish "$APP_PROJECT" -c Release -r win-x64 --self-contained true -o "$PUBLISH"

python3 - "$SECRETS" "$CONFIG" << 'PY'
import pathlib, sys

def json_escape(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'

secrets, target = sys.argv[1:]
url, key = "", ""
text = pathlib.Path(secrets).read_text(encoding="utf-8") if pathlib.Path(secrets).exists() else ""
for line in text.splitlines():
    raw = line.strip()
    if not raw or raw.startswith("//") or "=" not in raw:
        continue
    name, value = raw.split("=", 1)
    value = value.strip().replace("/$()/", "//")
    if name.strip() == "SUPABASE_URL":
        url = value
    elif name.strip() == "SUPABASE_ANON_KEY":
        key = value
path = pathlib.Path(target)
path.write_text(
    '{\n  "supabaseUrl": ' + json_escape(url) + ',\n  "supabaseAnonKey": ' + json_escape(key) + '\n}\n',
    encoding="utf-8",
)
print("config", "ok" if url.startswith("https://") and key and "YOUR_" not in key else "missing")
PY

rm -f "$PAYLOAD"
(cd "$PUBLISH" && zip -r -q "$PAYLOAD" .)

"$DOTNET" publish "$SETUP_PROJECT" -c Release -r win-x64 --self-contained true \
  -p:PublishSingleFile=true \
  -p:IncludeNativeLibrariesForSelfExtract=true \
  -p:EnableCompressionInSingleFile=true \
  -p:PayloadZip="$PAYLOAD" \
  -o "$BUILD/setup"

cp "$BUILD/setup/ERPMobile.Setup.exe" "$KIT"
rm -f "$ROOT/Kit instalare/ERP Mobile Setup.exe"
echo "Kit: $KIT"
