# 루티니티 프론트엔드 로드맵 (10일)

담당: 나 (백엔드 완성, 프론트 병행) | 원래 프론트 팀원과 화면 분담 조율 예정
스택: SwiftUI + MVVM, 백엔드는 완성된 Supabase API 사용 (docs/api-contract.md 참고)

---

## 0. 아키텍처 한눈에

```
SwiftUI View  →  ViewModel  →  API Client  →  Supabase 백엔드 (완성됨)
 (화면만)      (상태·로직)    (네트워크 요청)      (이미 배포됨)
```

- View: UI만 그림, 로직 없음
- ViewModel: `@Published` 상태 보유, 버튼 액션 처리
- API Client: `/logs`, `/goals`, `/scores`, `/reports/weekly` 호출
- 인증: Supabase Auth SDK (supabase-swift 패키지) 사용

---

## 1. 화면 목록 & 연결 API

| 화면 | 설명 | API |
|---|---|---|
| 로그인/가입 | Supabase Auth | Auth SDK |
| 홈 | 원탭 기록 버튼(기상/식사/공부시작·종료) | `POST /logs` |
| 오늘 타임라인 | 오늘 기록 리스트 | `GET /logs?date=` |
| 목표 설정 | 대조군 값 입력/조회 | `POST/GET /goals` |
| 회고/점수 | 오늘 점수 표시 | `GET /scores` |
| 주간 리포트 | AI 리포트 텍스트 | `GET /reports/weekly` |

---

## 2. 10일 타임라인

| Day | 작업 | 완료 기준 |
|---|---|---|
| 1 | Xcode 프로젝트 생성, supabase-swift SDK 연동, 프로젝트 구조(View/ViewModel/Service 폴더) | 빌드 성공, 빈 화면 하나 실행 확인 |
| 2 | 로그인/가입 화면 (Supabase Auth) | 실제 가입→로그인→세션 유지 확인 |
| 3-4 | 홈 화면: 원탭 기록 버튼 4개 + `/logs` 연동 | 버튼 누르면 실제 DB에 로그 쌓이는지 확인 |
| 5 | 오늘 타임라인 화면 (`GET /logs`) | 기록한 로그가 리스트로 보임 |
| 6 | 목표 설정 화면 (`/goals`) | 목표값 저장/수정 가능 |
| 7-8 | 회고/점수 화면 (`GET /scores`) | 목표 대비 점수 표시 |
| 9 | 주간 리포트 화면 (`GET /reports/weekly`) | AI 리포트 텍스트 화면에 표시 |
| 10 | 전체 통합 테스트, 버그 픽스, 팀원 화면과 병합 | 기록→회고→리포트 전체 플로우 한 번에 확인 |

> 팀원과 화면을 나눠 가졌다면 이 표에서 겹치는 화면은 조율해서 조정하세요.

---

## 3. 체크리스트

- [ ] Xcode 프로젝트 + supabase-swift SDK 연동
- [ ] 로그인/가입 화면
- [ ] 홈 화면 (기록 버튼 4개)
- [ ] 오늘 타임라인 화면
- [ ] 목표 설정 화면
- [ ] 회고/점수 화면
- [ ] 주간 리포트 화면
- [ ] 전체 통합 테스트
- [ ] 팀원 작업물과 병합

---

## 4. 진행 팁

- 백엔드 만들 때처럼 Claude Code한테 `@docs/api-contract.md` 참고해서 화면 하나씩 만들어달라고 하면 됨
- 화면 하나 끝날 때마다 실제 기기/시뮬레이터에서 눌러보고 확인 — API 연동은 눈으로 보기 전엔 믿지 않기
- 스위프트 문법 몰라도 괜찮음, Claude Code가 코드 짜고 diff로 보여줄 때 "이게 뭐 하는 코드야?" 물어보면서 진행하면 됨
