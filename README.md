# n8n Crashlytics Auto Triage (Slack Events 기반)

이 레포는 `Slack Events -> n8n -> OpenAI/Slack/GitHub API` 흐름으로 Crashlytics 이슈 대응을 자동화합니다.

현재 기본 구조:
- 입력: Slack 채널 메시지 이벤트
- 처리: 원인 분석/조치안 생성, GitHub Issue/브랜치/커밋/푸시
- 출력: 동일 Slack 스레드에 분석/완료 댓글

중요: 현재 운영 기준에서 **Google Cloud webhook 연동은 필수 아님** (Slack Events 단일 경로).

## 빠른 시작

1. 환경 파일 준비
```bash
cp .env.example .env
```

2. `.env` 필수 값 입력
- `N8N_ENCRYPTION_KEY`
- `TARGET_REPO_PATH`
- `OPENAI_API_KEY`
- `SLACK_BOT_TOKEN`
- `GITHUB_TOKEN`
- `GITHUB_OWNER`
- `GITHUB_REPO`
- `SLACK_DEFAULT_CHANNEL_ID`

3. 스택 기동
```bash
docker compose up -d
```

4. n8n에서 워크플로우 import/활성화
- `workflows/crashlytics-auto-triage.json` (활성화)
- `workflows/slack-events-ingest.json` (활성화)
- `workflows/crashlytics-auto-triage-error.json` (선택)

5. Slack App Event Subscriptions 설정
- Request URL 등록, bot events/scopes 설정, 앱 재설치, 채널 봇 초대
- 상세 절차: `docs/operations/slack-events-runbook.md` (Slack Events 운영 가이드)

## 운영 문서

- 상세 운영/장애 대응 문서: `docs/operations/slack-events-runbook.md` (Slack Events 운영 가이드)
- 재부팅 복구 스킬: `~/.codex/skills/n8n-reboot-recovery/SKILL.md`

## 로컬 스킬 포함/설치

이 레포는 `n8n-reboot-recovery` 스킬을 `skills/n8n-reboot-recovery` 경로로 함께 버전관리합니다.

- 레포 스킬을 Codex 로컬 경로로 설치:
```bash
./scripts/install_skills.sh n8n-reboot-recovery
```

- 레포의 모든 스킬 설치:
```bash
./scripts/install_skills.sh
```

- 설치 위치:
  - 기본: `~/.codex/skills`
  - `CODEX_HOME` 지정 시: `$CODEX_HOME/skills`

## 재부팅/중단 복구

Codex에서 다음 한 줄로 복구:
- `$n8n-reboot-recovery`

복구 결과로 출력되는 `WEBHOOK_URL_SLACK_EVENTS`를 Slack App Request URL에 반영하면 됩니다.

## 브랜치 규칙 (중요)

- 브랜치명: `#<issue_number>`
- 쉘 명령에서 반드시 따옴표 사용:
```bash
git checkout -b '#1212'
git push origin '#1212'
```
- URL에서는 `#`를 `%23`으로 인코딩

## 참고

- 상세 체크리스트/트러블슈팅은 README에 중복 작성하지 않고 Runbook을 단일 기준으로 유지합니다.
