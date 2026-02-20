#!/bin/sh
set -eu

BRANCH_NAME="${1:-}"
ISSUE_NUMBER="${2:-}"
ISSUE_ID="${3:-}"
TARGET_REPO="/workspace/target-repo"
DEFAULT_BRANCH="${TARGET_REPO_DEFAULT_BRANCH:-main}"

if [ -z "${BRANCH_NAME}" ] || [ -z "${ISSUE_NUMBER}" ] || [ -z "${ISSUE_ID}" ]; then
  echo "usage: $0 <branch_name> <issue_number> <issue_id>" >&2
  exit 1
fi

cd "${TARGET_REPO}"

# Container bind-mount paths can trigger Git's dubious ownership protection.
git config --global --add safe.directory "${TARGET_REPO}" || true

git config user.name "${GIT_USER_NAME:-elecvery-bot}"
git config user.email "${GIT_USER_EMAIL:-elecvery-bot@example.com}"

REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
USE_HTTP_AUTH="false"
case "${REMOTE_URL}" in
  https://github.com/*|https://*.github.com/*)
    USE_HTTP_AUTH="true"
    ;;
esac

git_auth() {
  if [ -n "${GITHUB_TOKEN:-}" ] && [ "${USE_HTTP_AUTH}" = "true" ]; then
    AUTH_HEADER="Authorization: Basic $(printf 'x-access-token:%s' "${GITHUB_TOKEN}" | base64 | tr -d '\n')"
    git -c "http.extraheader=${AUTH_HEADER}" "$@"
    return
  fi
  git "$@"
}

git_auth fetch origin
# IMPORTANT: keep branch name quoted because names like '#1212' are valid and must not be treated as shell comments.
git checkout -B "${BRANCH_NAME}" "origin/${DEFAULT_BRANCH}"

git add -A

if git diff --cached --quiet; then
  echo "NO_CHANGES=true"
  echo "BRANCH=${BRANCH_NAME}"
  exit 0
fi

git commit -m "Fix: #${ISSUE_NUMBER} auto fix for Crashlytics ${ISSUE_ID}"
git_auth push -u origin "${BRANCH_NAME}"

echo "NO_CHANGES=false"
echo "BRANCH=${BRANCH_NAME}"
echo "COMMIT_SHA=$(git rev-parse HEAD)"
