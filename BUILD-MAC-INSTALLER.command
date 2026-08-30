#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/build-mac-installer.sh
./scripts/build-mac-installer.sh "$@"
echo ""
read -r -p "Apasă Enter pentru a închide..."
