---
description: "Team 기반 자율 디자인 (기획자 + 디자이너 N명 협업 → 시안 → 승인 → 전체 적용)"
argument-hint: "<텍스트 설명 / 기획서 경로 / 이미지 경로 (혼합 가능)> [시안 N개]"
---

# Auto Design

**기획자 1명 + 디자이너 N명이 팀으로 협업하여 디자인을 자율 생성하고, 승인 후 전체 화면에 적용합니다.**

## 시안 개수

입력에서 "시안 N개", "N개 시안", "N안" 등의 패턴으로 시안 개수를 지정할 수 있습니다.
- 기본값: 2개 (디자이너 2명)
- 최소: 1개, 최대: 10개
- 디자이너 수 = 시안 개수 (1:1 매핑)

## 사용법

```
/auto:auto-design 피팅 화면 전체 리디자인
/auto:auto-design 피팅 화면 리디자인 시안 5개
/auto:auto-design docs/idea/magazine.md 3안
/auto:auto-design assets/reference.png 이 느낌으로 시안 4개
/auto:auto-design docs/idea/fitting.md assets/ref.png 밝은 톤 7안
```

## 진행 단계

1. **온보딩** — 입력 해석, 사용자 확인
2. **팀 토론** — 기획자 분석 → 디자이너 2명 시안 제안 → 내부 리뷰 (자율)
3. **산출물 & 리뷰** — HTML 시안 생성 → 사용자 선택
4. **전체 적용** — 스타일 + 레이아웃 + 컴포넌트 일괄 적용
5. **결과 보고서** — 팀 토론 요약, 변경 파일, 작업 내역

## 산출물

- `docs/design/[날짜]-design-candidates.html` — 디자인 시안 비교
- `docs/style/guide.md` — 스타일 가이드
- `docs/style/preview.html` — 스타일 프리뷰
- `docs/reports/[날짜]-design-report.md` — 결과 보고서

## 실행 지시

design-director 에이전트를 Agent 도구로 호출하세요:

- subagent_type: `design-director`
- prompt: `$ARGUMENTS`
- mode: `bypassPermissions`

에이전트가 팀을 생성하고 5단계를 자율적으로 진행합니다.
온보딩과 시안 리뷰 단계에서만 사용자에게 질문합니다.
