#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "========================================"
echo "  ERP Mobile — Golire date BUNATATI"
echo "========================================"
echo ""

exec python3 "${ROOT_DIR}/scripts/wipe-company-via-api.py" "bunatati*maria"
