#!/usr/bin/env bash
set -euo pipefail

N8N_WEBHOOK_URL="${1:-http://localhost:5678/webhook/crashlytics-webhook}"
PAYLOAD_FILE="${2:-./payloads/crashlytics-sample.json}"

if [[ ! -f "${PAYLOAD_FILE}" ]]; then
  echo "payload not found: ${PAYLOAD_FILE}" >&2
  exit 1
fi

curl -sS -X POST "${N8N_WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  --data-binary "@${PAYLOAD_FILE}"

echo
echo "smoke webhook sent to ${N8N_WEBHOOK_URL}"
