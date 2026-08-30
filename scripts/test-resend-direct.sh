#!/usr/bin/env bash
# Testează trimiterea email prin Resend API (fără login Supabase).
# Necesită cheia API din Resend → API keys (permisiune Sending).
set -euo pipefail

read -r -p "Destinatar test [ERPMobile@dateconta.ro]: " TEST_TO
TEST_TO="${TEST_TO:-ERPMobile@dateconta.ro}"

if [[ -z "${RESEND_API_KEY:-}" ]]; then
  read -r -s -p "Resend API key (re_...): " RESEND_API_KEY
  echo ""
fi

if [[ -z "${RESEND_API_KEY:-}" ]]; then
  echo "Lipsește RESEND_API_KEY."
  echo "Exemplu: RESEND_API_KEY=re_abc123... bash scripts/test-resend-direct.sh"
  exit 1
fi

if [[ "${RESEND_API_KEY}" == *"COPIAZA"* ]] || [[ "${RESEND_API_KEY}" == "re_..." ]] || [[ ${#RESEND_API_KEY} -lt 20 ]]; then
  echo "Cheia API pare invalidă."
  echo "Nu folosi placeholder-ul re_... — copiază cheia COMPLETĂ din Resend → API keys."
  echo "Cheia se vede o singură dată la creare (buton Copy)."
  exit 1
fi

FROM="${EMAIL_FROM:-ERP Mobile <ERPMobile@dateconta.ro>}"

echo "Trimit email de test către ${TEST_TO}..."
RESULT=$(curl -sS -X POST "https://api.resend.com/emails" \
  -H "Authorization: Bearer ${RESEND_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(python3 - <<PY
import json
print(json.dumps({
    "from": "${FROM}",
    "to": ["${TEST_TO}"],
    "subject": "Test ERP Mobile — Resend direct",
    "text": "Dacă primiți acest email, domeniul dateconta.ro și Resend funcționează corect.",
}))
PY
)")

echo "${RESULT}" | python3 -m json.tool 2>/dev/null || echo "${RESULT}"

if echo "${RESULT}" | python3 -c "import sys,json; d=json.load(sys.stdin); raise SystemExit(0 if d.get('id') else 1)" 2>/dev/null; then
  echo ""
  echo "OK — email trimis. Verifică inbox/spam la ${TEST_TO}."
else
  exit 1
fi
