---
description: "Product Team 소환 (기획/디자인/개발/버그 TF 구성)"
argument-hint: "<자연어로 요구사항 입력>"
---

# Product Team

**Product Team을 소환하여 요구사항에 맞는 TF를 구성하고 자율적으로 진행합니다.**

## 사용법

```
/team:product 로그인 기능 만들어줘
/team:product 대시보드 UX가 불편해, 개선해줘
/team:product login 개발 진행해
/team:product 로그인 시 500 에러 발생
/team:product login 승인
/team:product login 반려, 소셜 로그인도 포함해줘
```

## 실행 지시

product-team 에이전트를 Agent 도구로 호출하세요:

- subagent_type: `product-team`
- prompt: `$ARGUMENTS`
- mode: `bypassPermissions`

에이전트가 TeamCreate로 실제 팀을 구성하여 자율적으로 진행합니다.
