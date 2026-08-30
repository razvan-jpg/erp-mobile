#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/apply-nir-migrations.sh
./scripts/apply-nir-migrations.sh
echo ""
read -r -p "Apasă Enter pentru a închide..."
