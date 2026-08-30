#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/empty-database.sh
./scripts/empty-database.sh
echo ""
echo "Apasă Enter pentru a închide..."
read -r
