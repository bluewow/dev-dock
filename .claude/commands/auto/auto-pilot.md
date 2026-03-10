---
description: PRD 기반 자율주행 구현 (신규 / 점진적 추가 / 이어하기)
argument-hint: "<PRD 파일 경로 또는 resume>"
---

# Autopilot

**PRD를 기반으로 자율주행 모드로 구현합니다.**
기존 작업이 있으면 자동으로 감지하여 점진적으로 추가하거나 이어서 진행합니다.

## 실행

`$ARGUMENTS`로 전달된 PRD 파일 경로(또는 `resume`)를 auto-pilot 에이전트에게 전달하여 실행합니다.

### 실행 모드

| 모드 | 조건 | 동작 |
|------|------|------|
| **신규** | plan.md 없음 | 전체 온보딩 → 자율주행 → 보고서 |
| **점진적 추가** | plan.md 있음 + 새 PRD 경로 | 경량 온보딩 → 기존 plan에 Sprint 추가 → 자율주행 → 보고서 |
| **이어하기** | `resume` 인자 | 미완료 Task부터 자율주행 재개 → 보고서 |

### 사용법

```
/auto:auto-pilot docs/prd/feature-a.md        # 최초 실행 (신규)
/auto:auto-pilot docs/prd/feature-b.md        # 기능 추가 (점진적)
/auto:auto-pilot docs/prd/feature-c.md        # 또 추가 (점진적)
/auto:auto-pilot resume                        # 중단된 작업 이어하기
```

### 모드 자동 판별

```
/auto:auto-pilot <파일경로>
  └─ plan.md 없음?  → 신규 모드
  └─ plan.md 있음?  → 점진적 추가 모드

/auto:auto-pilot resume
  └─ plan.md 있음 + 미완료 Task 있음?  → 이어하기 모드
  └─ plan.md 없음?                     → 에러 ("이어할 작업이 없습니다")
  └─ 전부 완료?                        → 안내 ("모든 Task가 완료되었습니다")
```

### 실전 시나리오

```bash
# 1일차: 핵심 기능 구현
/auto:auto-pilot docs/prd/core-fitting.md

# 2일차: 매거진 기능 추가
/auto:auto-pilot docs/prd/magazine.md

# 2일차: 컨텍스트 초과로 중단됨 → 이어하기
/auto:auto-pilot resume

# 3일차: 소셜 투표 추가
/auto:auto-pilot docs/prd/social-vote.md

# 4일차: 알림 기능 추가
/auto:auto-pilot docs/prd/notifications.md
```

### 산출물

- `docs/sprints/plan.md` — Sprint 계획 (누적, PRD별 Sprint 구간 표기)
- `docs/reports/[날짜]-auto-pilot-report.md` — 결과 보고서 (실행별, 같은 날 여러 번이면 -2, -3 접미사)

---

## PRD 작성법

`.claude/PRD.md` 참고. 자유 형식이며, 최소한 배경 + 목표 + 핵심 기능만 있으면 됩니다.

---

## 실행 지시

auto-pilot 에이전트를 Agent 도구로 호출하세요:

- subagent_type: `auto-pilot`
- prompt: `$ARGUMENTS` (PRD 파일 경로 또는 `resume`)
- mode: `bypassPermissions`

에이전트가 모드를 자동 판별하여 적절한 단계부터 진행합니다.
