#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/upload-email-confirm-page.sh
./scripts/upload-email-confirm-page.sh
echo ""
echo "Apasă Enter pentru a închide..."
read -r
