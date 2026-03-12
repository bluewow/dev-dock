# history.json 관리 규칙

> product-team 에이전트 및 관련 커맨드가 참조하는 이력 관리 규칙.

---

## 개요

- **history.json**: Claude가 읽고 쓰는 데이터. 상태 변경 시 JSON만 편집한다.
- **history.html**: 사용자가 브라우저에서 여는 뷰. JSON을 fetch하여 렌더링하므로 수정 불필요.

---

## history.json 형식

```json
[
  {
    "id": "001-login",
    "name": "로그인 기능",
    "path": "tasks/001-login",
    "logs": [
      { "phase": "기획", "status": "완료", "date": "2026-03-10", "note": "기획자A, 기획자B 참여" },
      { "phase": "디자인", "status": "완료", "date": "2026-03-10", "note": "디자이너A 주도" },
      { "phase": "승인", "status": "반려", "date": "2026-03-10", "note": "소셜 로그인 추가 요청" },
      { "phase": "디자인", "status": "완료", "date": "2026-03-11", "note": "소셜 로그인 반영, 이전 버전: design-v1.html" },
      { "phase": "승인", "status": "조건부승인", "date": "2026-03-11", "note": "비밀번호 찾기는 2차에서 구현" },
      { "phase": "개발", "status": "진행중", "date": "2026-03-11", "note": "" }
    ]
  }
]
```

---

## 현재 상태 판단 규칙

- 각 기능의 **마지막 log 항목**이 현재 상태를 나타낸다
- 태스크 폴더 내에 `spec.md`가 존재하면 승인 완료, 없으면 미승인

---

## 승인/반려 status 값

| 방법 | 예시 | status 값 |
|------|------|-----------|
| 승인 | `"login 승인"` | `승인` |
| 조건부 승인 | `"login 승인, 단 비밀번호 찾기는 2차에서"` | `조건부승인` |
| 반려 | `"login 반려, 소셜 로그인도 포함해야 해"` | `반려` |

---

## 업데이트 절차

1. `{DOCS_ROOT}/history.json`을 **Read** 도구로 읽는다
2. JSON을 파싱한다
3. 해당 태스크의 `logs` 배열에 새 로그를 추가한다
4. **Write** 도구로 전체 JSON을 덮어쓴다

**주의**: history.json의 기존 데이터를 절대 손실시키지 않는다. 항상 Read → 파싱 → 수정 → Write 순서를 지킨다.
