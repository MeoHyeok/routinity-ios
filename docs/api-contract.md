# API 계약 — /logs, /goals, /scores, /reports-daily, /reports-weekly, /reports-monthly, /insights

ROADMAP.md 2번 섹션의 초안을 실제 구현에 맞춰 확정한 문서. 이후 필드명/타입이 바뀌면 팀 채널에 즉시 공지.

**2026-08-18 대규모 갱신**: `sleep`/`meal_start`/`meal_end` 로그 타입, `time_breakdown`/`suggested_action` 리포트 필드, 그리고 아래 "하루의 정의" 섹션에 설명된 KST 세션 모델까지 이번에 한 번에 반영. 그 이전 버전(고정 `UTC 기준` 날짜 경계, `meal` 단일 타입, `time_breakdown`/`suggested_action` 없음)을 기억하고 있다면 전부 무효.

## 공통

- **Base URL**: `https://noqvrfewkyfdrsoaszmz.supabase.co`
- **anon key** (Supabase Auth SDK 초기화용): `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5vcXZyZmV3a3lmZHJzb2Fzem16Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYzMzA3NDksImV4cCI6MjEwMTkwNjc0OX0.rAZiVgHR1FLs66wNEiW28WERlY1NZEi__Y3iGk_-1kk`
- **인증**: Supabase Auth로 로그인해서 받은 `access_token`을 모든 요청에 `Authorization: Bearer <access_token>` 헤더로 포함. 헤더가 없거나 유효하지 않으면 `401`.
- **에러 응답 형식**: `{ "error": "설명 문자열" }` (401은 플랫폼 레벨 응답이라 `{ "code": "...", "message": "..." }` 형식일 수 있음)
- **레이트리밋**: 유저별·엔드포인트별 1분 고정 윈도우. 초과 시 `429` + `{ "error": "rate limit exceeded, try again later" }`. 앱에서 429를 받으면 짧게 재시도하지 말고 사용자에게 "잠시 후 다시 시도" 정도로 안내 권장. 엔드포인트별 한도:
  - `/logs`: 60회/분
  - `/goals`: 20회/분
  - `/scores`: 60회/분
  - `/reports-daily`, `/reports-weekly`, `/reports-monthly`: 각 10회/분 (하루 1회만 실제 생성되고 나머지는 캐시 응답이라 넉넉함)
  - `/insights`: 20회/분

### 하루의 정의 (KST 세션 모델)

"하루"는 UTC나 KST 같은 고정된 시각 경계로 나뉘지 않는다. 대신 유저의 "기상 로그 → 다음 취침 로그"가 하나의 세션이고, 그 세션이 그날의 데이터 단위다. 자정을 넘겨 자도 세션이 갈라지지 않고, 세션의 날짜 라벨은 그 세션을 연 기상 로그의 KST(한국시간) 캘린더 날짜다. 기상 로그가 없는 날은 그날의 세션 자체가 없어서 관련 데이터가 전부 빈 상태로 나온다.

이 모델을 따르는 엔드포인트: `GET /logs`, `GET /scores` (`date=` 파라미터가 "그 KST 날짜에 기상한 세션"을 찾음), `GET /reports-daily`(항상 "오늘"의 세션, 아래 참고), `/reports-weekly`·`/reports-monthly`·`/insights`(윈도우 내 세션들을 집계).

**엔드포인트 간 세션 불일치 수정 (2026-08-19, iOS 통합 테스트 중 발견)**: 세션 방식으로 바뀐 뒤에도, 각 엔드포인트가 세션을 계산하기 전에 로그를 얼마나 과거까지 조회하는지가 엔드포인트마다 달랐음 — `/reports-daily`는 "어제 KST 자정"부터, `GET /logs?date=`·`/scores`는 조회하는 그 날짜의 KST 자정부터(과거 조회 없음)만 로그를 가져왔음. 그 결과 취침 로그 없이 다음 KST 날짜로 넘어간 열린 세션이 있을 때, 조회 범위가 그 세션의 시작(기상) 시점을 포함하는 엔드포인트는 "오늘 세션 없음"으로 올바르게 판정하지만, 포함하지 않는 엔드포인트는 다음 날의 기상 로그를 (잘못) 새 세션으로 오판해서 — 같은 계정, 같은 로그인데 `GET /logs?date=`엔 기상 로그가 보이고 `/reports-daily`엔 "기록 없음"으로 나오는 불일치가 발생함. `SESSION_LOOKBACK_MS`(24시간)를 도입해 세션 계산 전 로그 조회 범위를 모든 day-bucketing 엔드포인트(`/logs`, `/scores`, `/reports-daily`, `/reports-weekly`, `/reports-monthly`, `/insights`)에서 일관되게 24시간 더 과거로 확장 — 이 값이 세션 하나가 "새 기상 로그를 계속 흡수하며 살아있을 수 있는" 최대 시간과 같기 때문에, 이만큼만 과거로 봐도 전체 로그 히스토리를 다 봤을 때와 동일한 세션 판정이 보장됨. 응답 필드/형식 변경 없음, 세션 판정 로직만 통일.

**`autoClosed`(자동 종료), 2026-08-19**: 취침 로그를 아예 안 남기는 계정은 위 수정 이후에도 그 세션이 영원히 "열린 채"로 남는 문제가 있었음(다음 기상 로그가 24시간 이상 지나서 와야만 강제로 분리됨). `computeDaySessions`가 이제 마지막으로 열려 있는 세션에 대해, 열린 지 24시간이 지나면(=세션을 처음 연 기상 로그의 timestamp 기준, 그 뒤 흡수된 기상 로그로 갱신되지 않음) 내부적으로 "자동 종료"로 표시함. **API 응답으로는 노출되지 않는 순수 내부 계산값**이며, 실제 `sleep` 로그를 합성해서 DB에 넣지도 않음(그 세션의 `daily_score`엔 영향 없고, `time_breakdown`은 실제 취침 시각을 모르므로 계속 `null`). 클라이언트가 "곧 자동 마감된다"는 걸 보여주려면 서버 필드 없이 그 세션의 첫 기상 로그 timestamp(`GET /logs?date=` 응답의 첫 로그) + 24시간으로 직접 계산하면 됨.

## POST /functions/v1/logs

이벤트 기록 (기상/취침/식사 시작·종료/공부 시작·종료)

**요청 헤더**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**요청 바디**
```json
{ "type": "study_start", "timestamp": "2026-08-10T09:00:00Z" }
```

- `type`: `"wake" | "sleep" | "meal_start" | "meal_end" | "study_start" | "study_end"` (필수, 이 외 값이면 400). 구버전의 단일 `meal` 타입은 더 이상 POST로 받지 않음(400) — 과거에 찍힌 `meal` 로그는 DB에 남아있고 `GET`으로는 계속 읽힘
- `timestamp`: ISO 8601 문자열 (필수, 파싱 불가하면 400)

**응답 201**
```json
{
  "id": "d5d2610c-edc6-445d-bece-c024b36f9218",
  "type": "study_start",
  "timestamp": "2026-08-10T09:00:00+00:00",
  "created_at": "2026-08-10T07:43:47.276861+00:00"
}
```

`id`는 uuid. ROADMAP 초안의 `log_abc123` 형식이 아니라 uuid로 확정.

## GET /functions/v1/logs?date=YYYY-MM-DD

`date`로 넘긴 KST 캘린더 날짜에 기상한 세션의 로그 조회 (위 "하루의 정의" 참고 — 고정 시각 경계가 아니라 세션 기준).

**요청 헤더**
```
Authorization: Bearer <access_token>
```

`date` 쿼리 파라미터 필수 (`YYYY-MM-DD` 형식 아니면 400).

**응답 200**
```json
[
  { "id": "...", "type": "study_start", "timestamp": "2026-08-10T09:00:00+00:00", "created_at": "..." }
]
```

시간순 정렬. 그 날짜에 기상한 세션이 없으면 빈 배열.

## DELETE /functions/v1/logs?id=&lt;uuid&gt;

잘못 기록한 로그 삭제. `id`는 `POST`/`GET /logs` 응답의 `id` 값(uuid).

**요청 헤더**
```
Authorization: Bearer <access_token>
```

- `id` 쿼리 파라미터 필수 (uuid 형식 아니면 400)
- 삭제 성공 시 **204 No Content** (바디 없음)
- 존재하지 않거나 본인 소유가 아니면 **404** `{ "error": "log not found" }` — 다른 유저의 로그 id를 넣어도 RLS로 인해 항상 404 (존재 여부 자체를 노출하지 않음)

---

## POST /functions/v1/goals

목표(대조군) 설정. **upsert 동작** — 같은 `target_type`으로 다시 POST하면 새로 생기지 않고 기존 값이 갱신됨 (유저당 `target_type`별로 항상 최대 1개).

**요청 헤더**
```
Authorization: Bearer <access_token>
Content-Type: application/json
```

**요청 바디**
```json
{ "target_type": "wake_time", "target_value": "07:00" }
```

- `target_type`: 문자열, 필수. `wake_time`, `study_duration` 등 — 고정 enum 아님, 새로운 타입 자유롭게 추가 가능
- `target_value`: 문자열, 필수. `wake_time`/`study_duration`는 채점 로직이 파싱 가능한 형식을 서버에서 강제함 (그 외 target_type은 형식 제약 없이 임의 문자열 허용):
  - `wake_time`: `HH:MM` 24시간제 (예: `"07:00"`). 형식 아니면 400 `{ "error": "target_value must be HH:MM (24h)" }`
  - `study_duration`: 1 이상 정수 문자열, 분 단위 (예: `"60"`). 아니면 400 `{ "error": "target_value must be a positive integer (minutes)" }`

**응답 200** (생성이든 갱신이든 200 — "지금 이 목표값은 이것"이라는 현재 상태 응답이라 201/200 구분 안 함)
```json
{
  "id": "3d6b0d3c-178d-45c0-bfa9-80795e9dc16d",
  "target_type": "wake_time",
  "target_value": "06:30",
  "updated_at": "2026-08-10T08:01:19.828+00:00"
}
```

## GET /functions/v1/goals

로그인한 유저의 모든 목표 조회.

**요청 헤더**
```
Authorization: Bearer <access_token>
```

**응답 200**
```json
[
  { "id": "...", "target_type": "study_duration", "target_value": "120", "updated_at": "..." },
  { "id": "...", "target_type": "wake_time", "target_value": "06:30", "updated_at": "..." }
]
```

`target_type` 기준 정렬. 설정한 목표가 없으면 빈 배열. (내부적으로 `created_at`도 갖고 있음 — 목표 소급 적용 방지에 쓰이지만 응답 필드로는 노출 안 됨.)

## DELETE /functions/v1/goals?target_type=&lt;string&gt;

목표 추적 중단(완전 삭제). `target_value`만 덮어쓰는 POST와 달리 row 자체를 지운다 — 삭제 후 같은 target_type으로 다시 POST하면 새 id로 새로 생성됨.

**요청 헤더**
```
Authorization: Bearer <access_token>
```

- `target_type` 쿼리 파라미터 필수 (없으면 400)
- 삭제 성공 시 **204 No Content** (바디 없음)
- 해당 target_type의 목표가 없으면 **404** `{ "error": "goal not found" }` (다른 유저 소유인 경우도 RLS로 동일하게 404)

---

## GET /functions/v1/scores?date=YYYY-MM-DD

`date`로 넘긴 KST 캘린더 날짜에 기상한 세션의 목표 대비 점수 조회. 유저가 설정한 목표(`/goals`)와 그 세션의 로그를 비교해서 계산.

**요청 헤더**
```
Authorization: Bearer <access_token>
```

`date` 쿼리 파라미터 필수 (`YYYY-MM-DD`).

**응답 200**
```json
{
  "date": "2026-08-10",
  "daily_score": 50,
  "scores": [
    { "target_type": "wake_time", "target_value": "07:00", "actual_value": "06:50", "status": "achieved" },
    { "target_type": "study_duration", "target_value": "60", "actual_value": "30", "status": "not_achieved" }
  ]
}
```

- `status`: `"achieved" | "not_achieved" | "missing"`
  - `achieved`: 그 세션의 실측값이 목표 충족
  - `not_achieved`: 로그는 있지만 목표 미달
  - `missing`: 그 날짜에 기상한 세션이 아예 없음 (미달과 구분됨)
- `actual_value`: `missing`일 땐 항상 `null`
- 현재 채점 로직은 `target_type`이 `wake_time`(로그의 `wake` 타임스탬프, 목표보다 이르거나 같으면 achieved) / `study_duration`(그 세션 `study_start`~`study_end` 쌍의 총합(분), 목표 이상이면 achieved)일 때만 동작. 그 외 `target_type`으로 설정한 목표는 `scores` 배열에서 제외됨(아직 채점 규칙 없음)
- 목표를 하나도 설정 안 한 유저는 `scores: []`, `daily_score: null`
- **`date`는 과거 아무 날짜나 조회 가능** (미래 날짜 제한 없음). 조회하는 `date`가 목표를 실제로 설정하기 이전이면, 그 목표는 `scores` 배열에서 제외됨(과거로 소급 적용돼서 `missing`으로 잘못 표시되는 것 방지 — `/insights`와 동일한 `goalsExistingBy` 규칙)
- **`daily_score`**: 그 세션에서 채점 가능한 목표들의 "목표별 근접도(0~1)"를 평균 내서 0~100 정수로 변환 — `round(목표별 credit 합 / 목표 개수 × 100)`. 목표별 credit:
  - `achieved` → 항상 1 (초과 달성해도 보너스 없음)
  - `missing` → 항상 0 (근접했는지 판단할 데이터 자체가 없음)
  - `study_duration`의 `not_achieved` → `실제 분 / 목표 분` 비율 (예: 60분 목표에 30분 → 0.5)
  - `wake_time`의 `not_achieved` → 목표시간보다 늦은 정도에 비례해 감소, 120분(2시간) 이상 늦으면 0
  - 채점 가능한 목표가 하나도 없으면(=`scores: []`) `null`
  - 목표가 1~2개뿐이라도 부분점수 덕분에 0/50/100처럼 딱 떨어지지 않고 임의의 정수(예: 58)로 나올 수 있음

---

## GET /functions/v1/reports-daily

**오늘**(항상 "오늘" — `date` 쿼리 파라미터를 받지 않음)의 목표 달성 현황을 요약한 AI 일간 리포트 조회. 조회 시점에 없으면 생성.

**요청 헤더**
```
Authorization: Bearer <access_token>
```

**응답 200 (신규 생성)**
```json
{
  "period": "daily",
  "date": "2026-08-14",
  "content": "오늘의 루티니티 리포트\n\n오늘의 루틴 점수: 75점\n\n기상 목표: 목표 07:00, 실제 06:00 — 달성\n공부 시간 목표: 목표 60, 실제 30 — 미달성",
  "time_breakdown": { "active_minutes": 540, "meal_minutes": 40, "study_minutes": 90, "rest_minutes": 410 },
  "suggested_action": "공부 시간이 목표보다 30분 부족했어요. 내일은 공부 시작 전에 타이머를 목표 시간에 맞춰보세요.",
  "cached": false,
  "generated_via": "claude" | "template"
}
```

**응답 200 (같은 세션 재조회 — 캐시됨)**
```json
{ "period": "daily", "date": "2026-08-14", "content": "...", "time_breakdown": {...}, "suggested_action": "...", "cached": true }
```

- **`date`는 오늘 벽시계 날짜가 아니라 실제로 채점된 세션의 날짜다.** `resolveTodaySession`이 먼저 "오늘 KST 날짜에 기상한 세션"을 찾고, 없으면 "어제 세션이 이미 닫혀 있고 그 취침 로그가 오늘 KST 자정 이후"인 경우에 한해 그 세션으로 폴백한다 — 자정을 막 넘겨 자고 바로 리포트를 열어봐도 방금 닫힌 세션이 빈 리포트 없이 나오게 하기 위함. 그래서 응답의 `date`가 어제 날짜로 나올 수 있고, API 소비자는 이 필드를 "이 리포트가 어느 날 얘기인지"로 읽어야지 항상 "오늘"이라고 가정하면 안 된다.
- 세션당 한 번만 생성 — 같은 유저가 같은 세션을 다시 GET하면 `cached: true`, 캐시된 `time_breakdown`/`suggested_action`도 생성 시점 값 그대로 (그 세션에 로그가 더 추가돼도 캐시는 안 바뀜)
- 해당 세션에 목표가 하나도 없으면 "목표가 없다"는 안내 문구 템플릿 반환
- AI 생성 실패 시 자동 템플릿 폴백, `generated_via`로 경로 확인 가능

## GET /functions/v1/reports-weekly

이번 주(오늘 포함 최근 7일) 목표 달성 현황을 요약한 AI 리포트 조회. 조회 시점에 없으면 생성.

**요청 헤더**
```
Authorization: Bearer <access_token>
```

**응답 200 (신규 생성)**
```json
{
  "period": "weekly",
  "content": "이번 주 루티니티 리포트\n\n기상 목표: 7일 중 2일 달성, 1일 미달, 4일 기록 없음\n공부 시간 목표: 7일 중 1일 달성, 1일 미달, 5일 기록 없음",
  "time_breakdown": { "active_minutes": 500, "meal_minutes": 35, "study_minutes": 80, "rest_minutes": 385 },
  "suggested_action": "...",
  "cached": false,
  "generated_via": "claude" | "template"
}
```

**응답 200 (같은 날 재조회 — 캐시됨)**
```json
{ "period": "weekly", "content": "...", "time_breakdown": {...}, "suggested_action": "...", "cached": true }
```

- 하루에 한 번만 생성. 같은 날 다시 GET하면 새로 생성하지 않고 `ai_reports`에 저장된 기존 리포트를 그대로 반환 (`cached: true`)
- 목표를 하나도 설정 안 했으면 "목표가 없다"는 안내 문구를 템플릿으로 반환
- **AI 생성 실패 시 자동으로 룰 기반 템플릿으로 폴백** (Claude API 키 미설정, 네트워크 오류, API 에러, refusal 전부 포함). 리포트 생성에 사용하는 모델: `claude-haiku-4-5-20251001`
- **패턴 반영**: `/insights`와 동일한 28일 데이터로 계산한 요일별 최고/최악, 최근 트렌드가 있으면 리포트 본문에 "패턴 분석" 섹션으로 덧붙음
- **"N일 중" 은 목표별로 실제 채점된 날짜 수**: 항상 7이 아니라 `달성+미달+기록없음` 합. 목표를 이번 주 중간에 설정했으면 그 이전 날짜는 아예 집계에서 빠지고(`/scores`와 동일한 `goalsExistingBy` 규칙), "N일 중" 숫자도 그만큼 줄어듦

## GET /functions/v1/reports-monthly

최근 30일(캘린더 월이 아니라 롤링 윈도우) 목표 달성 현황을 요약한 AI 월간 리포트 조회. weekly/daily와 동일하게 조회 시점에 없으면 생성.

**요청 헤더**
```
Authorization: Bearer <access_token>
```

**응답 200 (신규 생성)**
```json
{
  "period": "monthly",
  "date_range": { "from": "2026-07-16", "to": "2026-08-14" },
  "content": "최근 한 달 루티니티 리포트\n\n기상 목표: 최근 30일 중 7일 달성, 3일 미달, 20일 기록 없음\n\n패턴 분석\n금요일에 가장 잘 지키고(평균 50점), 화요일에 가장 많이 놓치는 편이에요(평균 0점).\n최근 일주일 평균이 지난주보다 올랐어요 (29점 → 43점).",
  "time_breakdown": { "active_minutes": 495, "meal_minutes": 38, "study_minutes": 75, "rest_minutes": 382 },
  "suggested_action": "...",
  "cached": false,
  "generated_via": "claude" | "template"
}
```

- **캘린더 월이 아니라 최근 30일 롤링 윈도우** — 가입한 지 한 달이 안 된 유저에게도 항상 꽉 찬 30일 기준으로 나옴
- `date_range`는 `/insights`와 같은 필드명(`from`/`to`)
- 하루에 한 번만 생성 — weekly/daily와 같은 `ai_reports` 유니크 인덱스로 DB 레벨에서 강제
- **"최근 N일 중"은 목표별로 실제 채점된 날짜 수** (`/reports-weekly`와 동일 규칙): 목표 설정 이전 날짜는 집계에서 제외되고, 그만큼 "N일" 숫자도 줄어듦 — 항상 30이 아님

### `time_breakdown` (daily/weekly/monthly 공통)

```
{ active_minutes: number, meal_minutes: number, study_minutes: number, rest_minutes: number } | null
```

- daily: 해당 세션 안에 기상+취침 로그가 둘 다 있어야 non-null
- weekly/monthly: 그 윈도우 안에서 기상+취침이 둘 다 있었던 날들의 일평균. 그런 날이 하나도 없으면 `null`
- 생성 시점에 `ai_reports`에 함께 저장돼서, 캐시 재조회로 나가는 응답의 값은 그 시점 그대로 고정 (그 뒤 로그가 추가돼도 안 바뀜)

### `suggested_action` (daily/weekly/monthly 공통)

`string | null` — 한 문장 정도의 다음 액션 제안. 엄격한 포맷 규칙은 없음. 채점 가능한 목표가 없거나 전부 이미 달성이면 `null`. Claude 경로는 프롬프트에서 응답 마지막 줄을 `ACTION: <문장>`으로 받아 추출하고, 실패/폴백 시엔 룰 기반(그 세션/윈도우에서 제일 못 지킨 목표 하나를 짚음)으로 채운다. `time_breakdown`과 마찬가지로 생성 시점에 저장되어 캐시 재조회로는 값이 안 바뀜.

---

## GET /functions/v1/insights

최근 28일 데이터 기반 요일별 평균 루틴 점수 + 최근 트렌드. 패턴 파악용, AI 리포트와 무관하게 즉시 계산되는 순수 통계 엔드포인트(Claude 호출 없음).

**요청 헤더**
```
Authorization: Bearer <access_token>
```

**응답 200**
```json
{
  "date_range": { "from": "2026-07-18", "to": "2026-08-14" },
  "weekday_averages": [
    { "weekday": 5, "label": "금", "avg_daily_score": 100, "days_counted": 1 }
  ],
  "best_weekday": { "weekday": 5, "label": "금", "avg_daily_score": 100 },
  "worst_weekday": { "weekday": 5, "label": "금", "avg_daily_score": 100 },
  "trend": { "direction": "up", "recent_avg": 70, "previous_avg": 55 }
}
```

- `weekday`: 0(일)~6(토), 세션 날짜(KST) 기준. `weekday_averages`는 요일 오름차순 정렬
- **집계 대상**: `daily_score`가 계산되는 세션만 포함. 목표를 하나도 설정 안 했으면 전부 제외, 그 목표를 실제로 설정하기 이전 날짜도 제외(`goalsExistingBy` 규칙)
- 요일별 데이터가 하나도 없으면 `weekday_averages: []`, `best_weekday`/`worst_weekday`: `null`
- `trend`: 최근 7일 평균 vs 그 이전 7일 평균. 두 구간 모두 데이터가 있어야 계산, 하나라도 없으면 `null`. 두 평균 차이가 3점 이하면 `"flat"`(반올림 노이즈로 오인 방지), 그보다 크면 `"up"`/`"down"`

---

## 구현 완료

로드맵의 4개 엔드포인트(`/logs`, `/goals`, `/scores`, `/reports-weekly`)를 시작으로, 삭제 기능(`DELETE /logs`, `DELETE /goals`), `daily_score`, `/reports-daily`, `/insights`, 리포트 패턴 반영, `/reports-monthly`, `time_breakdown`/`suggested_action`, 그리고 하루를 고정 시각 경계 대신 KST 세션으로 재정의한 것까지 전부 프로덕션에 배포·테스트 완료. iOS 클라이언트도 세 곳(LogsViewModel/ScoreViewModel/TrendViewModel)의 날짜 계산을 전부 KST 세션 모델에 맞춰 전환됨.

**2026-08-19**: iOS 통합 테스트 중 발견된 엔드포인트 간 세션 판정 불일치를 `SESSION_LOOKBACK_MS`로 수정, 취침 로그가 없는 세션의 내부 `autoClosed`(24시간) 처리 추가 — 둘 다 "하루의 정의" 섹션 참고. iOS 클라이언트도 LogsViewModel에 `loadTodayIncludingCarryover`를 추가해 취침 미기록으로 다음 KST 날짜까지 넘어간 열린 세션을 TodayView에서 인식하고, 자동 종료까지 남은 시간을 안내하는 배너를 표시하도록 대응.
