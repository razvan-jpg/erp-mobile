#!/usr/bin/env bash
# Instrucțiuni publicare pagină „Ce este nou” pe rincon.ro
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${ROOT_DIR}/web/news/index.html"
RINCON_URL="http://www.rincon.ro/news"

echo "========================================"
echo "  Pagină „Ce este nou” — rincon.ro"
echo "========================================"
echo ""
echo "Fișier sursă (editați aici noutățile):"
echo "  ${SOURCE}"
echo ""
echo "Publicare pe rincon.ro:"
echo ""
echo "  1. Conectați-vă la hosting-ul rincon.ro (FTP / cPanel / File Manager)"
echo "  2. Creați folderul „news” (dacă nu există) în rădăcina site-ului"
echo "  3. Încărcați fișierul ca:  news/index.html"
echo "  4. Verificați în browser: ${RINCON_URL}"
echo "     → trebuie să vedeți pagina de noutăți, NU cod HTML ca text"
echo ""
echo "Aplicația ERP Mobile încarcă automat această adresă în tab-ul „Ce este nou”."
