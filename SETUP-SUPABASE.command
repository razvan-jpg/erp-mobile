#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/supabase-setup.sh
./scripts/supabase-setup.sh
echo ""
echo "Apasă Enter pentru a închide..."
read -r
