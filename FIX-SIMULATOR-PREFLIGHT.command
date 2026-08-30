#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/run-simulator.sh scripts/fix-simulator-preflight.sh
./scripts/fix-simulator-preflight.sh
echo ""
echo "Apasă Enter pentru a închide..."
read -r
