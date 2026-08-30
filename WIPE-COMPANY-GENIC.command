#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/wipe-company-genic.sh
./scripts/wipe-company-genic.sh
echo ""
echo "Apasă Enter pentru a închide..."
read -r
