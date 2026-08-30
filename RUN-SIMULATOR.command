#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/run-simulator.sh
./scripts/run-simulator.sh
echo ""
echo "Apasă Enter pentru a închide..."
read -r
