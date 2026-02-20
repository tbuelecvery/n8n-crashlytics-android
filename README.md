# n8n Crashlytics Auto Triage (Self-Hosted)

Crashlytics webhook -> Slack thread RCA -> GitHub Issue -> `#<issue_number>` branch -> auto-fix/commit/push -> Slack completion reply.

## 1. What This Scaffold Includes

- `docker-compose.yml`: `n8n + postgres + redis` in queue mode
- `.env.example`: required environment variables
- `workflows/crashlytics-auto-triage.json`: main pipeline (import into n8n)
- `workflows/crashlytics-auto-triage-error.json`: error workflow (import into n8n)
- `scripts/apply_recommended_fix.sh`: project-specific fix hook + demo fallback
- `scripts/commit_and_push.sh`: branch checkout/commit/push wrapper
- `scripts/encode_branch_for_url.sh`: `#` -> `%23` utility
- `scripts/run_local_smoke.sh`: local webhook smoke test
- `payloads/crashlytics-sample.json`: sample payload

## 2. Architecture

- **Postgres**: workflow definitions, execution history, credentials metadata (persistent state)
- **Redis**: queue transport between n8n main and worker (execution coordination)
- **n8n main**: receives webhook and orchestrates flow
- **n8n worker**: performs long-running tasks (analysis/git operations)
- **Direct API calls from n8n**: Slack/GitHub/OpenAI are called from HTTP Request nodes (no MCP bridge dependency)

## 3. Prerequisites

- Docker Desktop
- Git push access to target repository
- API tokens:
  - Slack Bot Token (`chat:write`, `channels:history` or equivalent scope for target channel)
  - GitHub Token (`repo` scope for issues + branch push)
  - OpenAI API key

## 4. Local Setup

1. Copy env file.

```bash
cd automation/n8n-crashlytics
cp .env.example .env
```

2. Fill `.env` values.

Required minimum:
- `N8N_ENCRYPTION_KEY` (fixed secret, 32+ chars)
- `TARGET_REPO_PATH` (absolute path on your host)
- `OPENAI_API_KEY`
- `SLACK_BOT_TOKEN`
- `GITHUB_TOKEN`
- `GITHUB_OWNER`
- `GITHUB_REPO`
- `SLACK_DEFAULT_CHANNEL_ID` (optional but recommended)

3. Start stack.

```bash
docker compose up -d
```

4. Open n8n editor.
- `http://localhost:5678`

## 5. Import Workflows

1. Import `workflows/crashlytics-auto-triage.json`
2. Import `workflows/crashlytics-auto-triage-error.json`
3. Review every HTTP Request node URL/headers/body and required tokens
4. Activate both workflows

## 6. Branch Naming Rule (Critical)

Branch format is always:
- `#<issue_number>`
- Example: `#1212`

### Shell Safety Rule

`#` is a shell comment character if not quoted.
Always keep branch names quoted in shell commands.

```bash
git checkout -b '#1212'
git push origin '#1212'
```

### URL Rule

When building branch links, encode `#` as `%23`.

- Branch URL example:
  - `https://github.com/<owner>/<repo>/tree/%231212`

## 7. End-to-End Smoke Test

```bash
./scripts/run_local_smoke.sh
```

or

```bash
curl -X POST 'http://localhost:5678/webhook/crashlytics-webhook' \
  -H 'Content-Type: application/json' \
  --data-binary @payloads/crashlytics-sample.json
```

Expected flow:
1. Webhook accepted
2. issueId lock acquired
3. Slack thread resolved (direct Slack API)
4. AI analysis generated (OpenAI API)
5. RCA reply posted to Slack thread
6. GitHub issue created (direct GitHub API)
7. `#<issue_number>` branch pushed
8. auto-fix script executed
9. commit/push attempted
10. completion reply posted to Slack thread

## 8. Project-Specific Auto Fix Hook

The default `apply_recommended_fix.sh` behavior:
- If `./scripts/auto-fix-crashlytics.sh` exists in target repo, it is used.
- Otherwise, no code changes are made unless `AUTO_FIX_DEMO_MODE=true`.

To implement real fixes, add this file in target repo:

```bash
scripts/auto-fix-crashlytics.sh
```

Signature:

```bash
./scripts/auto-fix-crashlytics.sh <issue_id> <issue_number>
```

## 9. Migration Checklist (Other MacBook)

1. Install and run Docker Desktop
2. Clone this automation folder/repo
3. Clone target app repository
4. Copy `.env.example` -> `.env` and set local absolute paths
5. Use the **same** `N8N_ENCRYPTION_KEY` as original machine
6. Ensure Git auth is configured (SSH key or PAT)
7. `docker compose up -d`
8. Import both workflow JSON files
9. Verify Slack/GitHub/OpenAI token reachability
10. Run smoke test payload
11. Verify Slack reply, GitHub issue, branch creation, and push

## 10. Operational Notes

- Keep idempotency by `issueId` (already implemented with static global lock in workflow)
- For production, replace static lock with durable lock table (Postgres/Redis)
- Add retry policy per external call and per-node timeout
- Add alerting via error workflow
