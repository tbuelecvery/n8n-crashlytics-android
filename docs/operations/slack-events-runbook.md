# Slack Events 운영 가이드

이 문서는 `Slack Events -> n8n` 자동화 운영의 단일 기준 문서입니다.

## 1. 목적과 적용 범위

- 목적: Slack 채널에 올라온 Crashlytics 알림 메시지를 n8n 트리거로 처리
- 적용 범위: 초기 설정, 동작 검증, 재부팅 복구, 장애 대응
- 제외 범위: Google Cloud webhook 기반 운영 (현재 구조에서 사용하지 않음)

## 2. 최초 1회 설정

### 2.1 n8n 스택과 워크플로우 준비

1. 스택 실행
```bash
docker compose up -d
```
2. n8n 편집기 접속 (`http://localhost:5678`)
3. 워크플로우 가져오기(Import)
- `workflows/crashlytics-auto-triage.json`
- `workflows/slack-events-ingest.json`
- `workflows/crashlytics-auto-triage-error.json` (선택)
4. 워크플로우 활성화(Activate)
- 필수: `Crashlytics Auto Triage`, `Slack Events Ingest`
- 선택: `Crashlytics Auto Triage Error Handler`

### 2.2 Slack 앱 설정

1. `Event Subscriptions` 활성화
2. `Request URL` 입력
- 형식: `<TUNNEL_URL>/webhook/<slack-events-webhook-path>`
- 운영 시에는 복구 스킬 출력값 `WEBHOOK_URL_SLACK_EVENTS` 사용 권장
3. `Subscribe to bot events` 추가
- `message.channels`
- (프라이빗 채널 사용 시) `message.groups`
4. OAuth 권한(Scopes) 확인
- `chat:write`
- `channels:history`
- (프라이빗 채널 사용 시) `groups:history`
5. `Reinstall to Workspace` 실행
6. 대상 채널에 봇 초대
- `/invite @앱이름`

## 3. 일상 점검 항목

1. 컨테이너 상태 확인
```bash
docker compose ps
```
2. 터널 URL 상태 확인 (`/healthz` 응답 확인)
3. Slack `Request URL`이 현재 터널 URL과 일치하는지 확인

## 4. 재부팅 또는 중단 복구

Codex에서 아래 명령만 실행:
- `$n8n-reboot-recovery`

스킬을 아직 설치하지 않았다면 먼저 레포 기준으로 설치:
```bash
./scripts/install_skills.sh n8n-reboot-recovery
```

정상 실행 시 확인할 출력:
- `STATUS=ok`
- `TUNNEL_URL`
- `WEBHOOK_URL_SLACK_EVENTS`
- `MANUAL_1`, `MANUAL_2`, `MANUAL_3`

복구 후 순서:
1. Slack 앱의 `Request URL`을 `WEBHOOK_URL_SLACK_EVENTS`로 갱신
2. 필요 시 앱 재설치 + 채널 봇 초대 상태 확인
3. 테스트 이벤트 전송 후 n8n 실행 결과 확인

## 5. 동작 검증 방법

### 5.1 Slack URL 검증

- Slack 화면에서 `Request URL` 저장 시 `Verified` 상태여야 정상
- 실패 시 URL 오타, 공백, 만료된 터널 여부를 먼저 확인

### 5.2 이벤트 수신 검증

- 대상 채널에 루트 메시지 1건 전송
- n8n에서 아래 실행이 순서대로 성공하는지 확인
- `Slack Events Ingest`
- `Crashlytics Auto Triage`

## 6. 장애 대응

### 증상 1: `Request URL` 검증 실패

가능 원인:
- 터널 URL 변경 또는 만료
- URL에 공백 포함
- n8n 미기동

조치:
1. 복구 스킬 실행
2. `WEBHOOK_URL_SLACK_EVENTS` 다시 등록
3. `http://localhost:5678/healthz` 응답 확인

### 증상 2: Slack 이벤트는 들어오는데 triage가 실행되지 않음

가능 원인:
- `Slack Events Ingest`만 활성화됨
- 채널 필터(`SLACK_DEFAULT_CHANNEL_ID`) 불일치
- 봇 권한 또는 채널 초대 누락

조치:
1. `Crashlytics Auto Triage` 활성화 상태 확인
2. `.env`의 `SLACK_DEFAULT_CHANNEL_ID` 값 확인
3. Slack 앱 재설치 및 채널 봇 초대

### 증상 3: 재부팅 직후 `healthz` 실패

가능 원인:
- n8n 초기 부팅 지연

조치:
1. 복구 스킬 재실행
2. 필요 시 대기 시간 증가 후 재실행
```bash
WAIT_N8N_SECONDS=180 AUTO_INSTALL_DEPS=true /Users/tbu/.codex/skills/n8n-reboot-recovery/scripts/recover_after_reboot.sh /Users/tbu/Documents/n8n-crashlytics-android QjqFiU4AS3RetyYG rz4ofhodZWIBPTBu
```

## 7. 보안 및 운영 주의사항

- 토큰/키는 `.env` 외부로 출력하지 않기
- 터널 URL은 재기동 시 변경될 수 있음
- 브랜치명 규칙은 `#<issue_number>` 유지
- 셸 명령에서는 `'#1212'`처럼 반드시 따옴표 사용
