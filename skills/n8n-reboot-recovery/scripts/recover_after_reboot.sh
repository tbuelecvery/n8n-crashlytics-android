#!/usr/bin/env bash
set -euo pipefail

REPO_PATH="${1:-/Users/tbu/Documents/n8n-crashlytics-android}"
TRIAGE_WORKFLOW_ID="${2:-QjqFiU4AS3RetyYG}"
SLACK_EVENTS_WORKFLOW_ID="${3:-rz4ofhodZWIBPTBu}"
N8N_PORT="${N8N_PORT:-5678}"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-true}"
WAIT_DOCKER_SECONDS="${WAIT_DOCKER_SECONDS:-180}"
WAIT_N8N_SECONDS="${WAIT_N8N_SECONDS:-90}"
START_TUNNEL="${START_TUNNEL:-true}"
WAIT_TUNNEL_SECONDS="${WAIT_TUNNEL_SECONDS:-45}"
TUNNEL_LOG="${TUNNEL_LOG:-/tmp/n8n-cloudflared.log}"

DOCKER_WAS_INSTALLED="false"
CLOUDFLARED_WAS_INSTALLED="false"

die() {
  echo "STATUS=error"
  echo "ERROR=$1"
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_brew() {
  has_cmd brew || die "homebrew not found; install Homebrew first"
}

ensure_cloudflared() {
  if has_cmd cloudflared; then
    return
  fi
  [ "${AUTO_INSTALL_DEPS}" = "true" ] || die "cloudflared command not found"
  ensure_brew
  brew install cloudflared >/dev/null
  has_cmd cloudflared || die "cloudflared install failed"
  CLOUDFLARED_WAS_INSTALLED="true"
}

ensure_docker_cmd() {
  if has_cmd docker; then
    return
  fi
  [ "${AUTO_INSTALL_DEPS}" = "true" ] || die "docker command not found"
  ensure_brew
  brew install --cask docker >/dev/null
  has_cmd docker || die "docker install failed"
  DOCKER_WAS_INSTALLED="true"
}

wait_for_docker() {
  local elapsed=0
  while [ "${elapsed}" -lt "${WAIT_DOCKER_SECONDS}" ]; do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
  return 1
}

ensure_docker_daemon() {
  if docker info >/dev/null 2>&1; then
    return
  fi
  open -a Docker >/dev/null 2>&1 || true
  wait_for_docker || die "docker daemon is not running; start Docker Desktop and retry"
}

ensure_docker_cmd
ensure_cloudflared
ensure_docker_daemon

docker compose version >/dev/null 2>&1 || die "docker compose is not available"
[ -d "${REPO_PATH}" ] || die "repo path not found: ${REPO_PATH}"

cd "${REPO_PATH}"
docker compose up -d >/dev/null

wait_for_n8n_health() {
  local elapsed=0
  local last_error="unknown"

  while [ "${elapsed}" -lt "${WAIT_N8N_SECONDS}" ]; do
    if curl -fsS "http://localhost:${N8N_PORT}/healthz" >/dev/null 2>/tmp/n8n-health.err; then
      return 0
    fi
    last_error="$(cat /tmp/n8n-health.err 2>/dev/null || true)"
    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo "DEBUG_N8N_HEALTH_LAST_ERROR=${last_error}" >&2
  docker compose ps >&2 || true
  docker compose logs --no-color --tail=40 n8n >&2 || true
  return 1
}

wait_for_n8n_health || die "n8n healthz check failed after ${WAIT_N8N_SECONDS}s"

extract_tunnel_url() {
  if [ ! -f "${TUNNEL_LOG}" ]; then
    return 0
  fi
  grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "${TUNNEL_LOG}" | head -n1
}

start_quick_tunnel() {
  local elapsed=0
  local url=""

  # Keep exactly one quick tunnel for this n8n port.
  pkill -f "cloudflared tunnel --url http://localhost:${N8N_PORT}" >/dev/null 2>&1 || true
  : > "${TUNNEL_LOG}"
  nohup cloudflared tunnel --url "http://localhost:${N8N_PORT}" --no-autoupdate >"${TUNNEL_LOG}" 2>&1 &
  TUNNEL_PID="$!"

  while [ "${elapsed}" -lt "${WAIT_TUNNEL_SECONDS}" ]; do
    url="$(extract_tunnel_url || true)"
    if [ -n "${url}" ]; then
      if ! kill -0 "${TUNNEL_PID}" >/dev/null 2>&1; then
        break
      fi
      TUNNEL_URL="${url}"
      return 0
    fi
    if ! kill -0 "${TUNNEL_PID}" >/dev/null 2>&1; then
      break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  echo "DEBUG_TUNNEL_LOG=${TUNNEL_LOG}" >&2
  tail -n 40 "${TUNNEL_LOG}" >&2 || true
  return 1
}

lookup_webhook_path() {
  local workflow_id="$1"
  local node_name="$2"
  local path
  path="$(docker compose exec -T postgres sh -lc \
    "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -At -c \
    \"select \\\"webhookPath\\\" from public.webhook_entity where \\\"workflowId\\\"='${workflow_id}' and node='${node_name}' limit 1;\"" 2>/dev/null || true)"
  echo "${path}" | tr -d '\r' | head -n1
}

TRIAGE_SUFFIX="$(lookup_webhook_path "${TRIAGE_WORKFLOW_ID}" "Webhook")"
[ -n "${TRIAGE_SUFFIX}" ] || TRIAGE_SUFFIX="${TRIAGE_WORKFLOW_ID}/webhook/crashlytics-webhook"

SLACK_EVENTS_SUFFIX="$(lookup_webhook_path "${SLACK_EVENTS_WORKFLOW_ID}" "SlackEventsWebhook")"
[ -n "${SLACK_EVENTS_SUFFIX}" ] || SLACK_EVENTS_SUFFIX="${SLACK_EVENTS_WORKFLOW_ID}/slackeventswebhook/slack-events"

WEBHOOK_PATH="/webhook/${TRIAGE_SUFFIX}"
WEBHOOK_PATH_SLACK_EVENTS="/webhook/${SLACK_EVENTS_SUFFIX}"
TUNNEL_URL=""
WEBHOOK_URL_SLACK_EVENTS=""

if [ "${START_TUNNEL}" = "true" ]; then
  start_quick_tunnel || die "cloudflared quick tunnel start failed"
  WEBHOOK_URL_SLACK_EVENTS="${TUNNEL_URL}${WEBHOOK_PATH_SLACK_EVENTS}"
fi

echo "STATUS=ok"
echo "REPO_PATH=${REPO_PATH}"
echo "N8N_HEALTH_URL=http://localhost:${N8N_PORT}/healthz"
echo "DOCKER_INSTALLED_NOW=${DOCKER_WAS_INSTALLED}"
echo "CLOUDFLARED_INSTALLED_NOW=${CLOUDFLARED_WAS_INSTALLED}"
echo "WEBHOOK_PATH=${WEBHOOK_PATH}"
echo "WEBHOOK_PATH_SLACK_EVENTS=${WEBHOOK_PATH_SLACK_EVENTS}"
echo "TUNNEL_URL=${TUNNEL_URL}"
echo "WEBHOOK_URL_SLACK_EVENTS=${WEBHOOK_URL_SLACK_EVENTS}"
echo "TUNNEL_LOG=${TUNNEL_LOG}"
echo "TUNNEL_COMMAND=cloudflared tunnel --url http://localhost:${N8N_PORT} --no-autoupdate"
if [ -n "${WEBHOOK_URL_SLACK_EVENTS}" ]; then
  echo "MANUAL_1=Slack App Event Subscriptions Request URL -> ${WEBHOOK_URL_SLACK_EVENTS}"
else
  echo "MANUAL_1=Slack App Event Subscriptions Request URL -> <TUNNEL_URL>${WEBHOOK_PATH_SLACK_EVENTS}"
fi
echo "MANUAL_2=Reinstall Slack app (if scopes/events changed) and invite bot to target channel"
echo "MANUAL_3=Send a test event and verify new n8n execution is success"
