#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/configure-resend.sh
./scripts/configure-resend.sh
echo ""
echo "Apasă Enter pentru a închide..."
read -r
