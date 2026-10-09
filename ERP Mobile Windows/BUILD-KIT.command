#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/build-kit.sh
./scripts/build-kit.sh
echo ""
read -r -p "Apasă Enter pentru a închide..."
