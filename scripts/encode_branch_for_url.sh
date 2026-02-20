#!/usr/bin/env bash
set -euo pipefail

BRANCH_NAME="${1:-}"
if [[ -z "${BRANCH_NAME}" ]]; then
  echo "usage: $0 <branch_name>" >&2
  exit 1
fi

# Minimal encoding for this rule set (#<issue_number>)
printf '%s\n' "${BRANCH_NAME//#/%23}"
