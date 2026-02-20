#!/usr/bin/env bash
set -euo pipefail

ISSUE_ID="${1:-}"
ISSUE_NUMBER="${2:-}"
TARGET_REPO="/workspace/target-repo"

if [[ -z "${ISSUE_ID}" || -z "${ISSUE_NUMBER}" ]]; then
  echo "usage: $0 <issue_id> <issue_number>" >&2
  exit 1
fi

cd "${TARGET_REPO}"

# Project-specific fix hook.
if [[ -x "./scripts/auto-fix-crashlytics.sh" ]]; then
  ./scripts/auto-fix-crashlytics.sh "${ISSUE_ID}" "${ISSUE_NUMBER}"
  exit 0
fi

# Demo fallback: write a trace line only when explicitly enabled.
if [[ "${AUTO_FIX_DEMO_MODE:-false}" == "true" ]]; then
  mkdir -p .automation
  printf '%s issue_id=%s issue_number=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${ISSUE_ID}" "${ISSUE_NUMBER}" >> .automation/n8n-crashlytics-demo.log
  echo "demo fix applied"
  exit 0
fi

echo "no project-specific auto-fix script found; skipping code changes"
