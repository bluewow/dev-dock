# TaskFlow - 구현 스펙

> 승인일: 2026-03-10
> 상태: 승인 완료

## 1. 개요

프로젝트 진행도와 TODO를 시각적으로 관리하는 단일 페이지 대시보드.
Next.js App Router + Tailwind CSS 기반 SPA.

## 2. 기술 스택

- **Framework**: Next.js 15 (App Router)
- **Styling**: Tailwind CSS v4
- **Font**: Pretendard (CDN)
- **Language**: TypeScript
- **Data**: localStorage (key: `taskflow-tasks`)
- **배포 대상**: 정적 export 가능

## 3. 데이터 모델

```typescript
interface Task {
  id: number;         // Date.now() 기반
  date: string;       // YYYY-MM-DD
  title: string;      // 최대 100자
  body: string;       // 최대 500자
  completed: boolean;
}
```

## 4. 화면 구조 (단일 페이지)

### 4-1. 상단 네비게이션
- 좌: 로고 아이콘(indigo-600 배경, 체크 SVG) + "TaskFlow" 텍스트
- 우: 알림 버튼 (아이콘만) + 프로필 아바타 (이니셜 "JD")

### 4-2. 프로젝트 진행도 섹션
- 좌: "Project Momentum" 제목 + "Daily task completion progress" 부제
- 우: 퍼센트 표시 (실시간 계산)
- 화살표 프로그레스 바:
  - clip-path polygon으로 화살표 형태
  - 배경: slate-200
  - 채움: indigo-500 -> purple-500 -> pink-500 그라데이션
  - 마일스톤 4개 (정적, 15%/40%/70%/90% 위치)
  - 마일스톤 포인트: w-4 h-4 (원본 w-3에서 확대)
  - 마일스톤 라벨: text-xs (원본 text-[10px]에서 확대)

### 4-3. 태스크 추가 폼 (lg:col-span-1)
- Due Date: date input (필수)
- Task Title: text input (필수, placeholder: "예: 디자인 리뷰")
- Details: textarea (선택, placeholder: "태스크 상세 설명...")
- Create Task 버튼: indigo-600, rounded-xl, shadow

### 4-4. 백로그 리스트 (lg:col-span-2)
- 헤더: "Your Backlog" + "Sort: Newest" 배지
- 태스크 카드:
  - 체크박스: w-6 h-6, 터치 영역 패딩 p-2 추가 (44px 확보)
  - 제목: font-bold, 완료 시 line-through
  - 날짜: text-xs text-indigo-500
  - 상세: text-sm text-slate-600
  - 삭제: 휴지통 아이콘, hover 시 red-500
  - 삭제 시: 확인 다이얼로그 표시 후 삭제
- 빈 상태: 클립보드 아이콘 + "아직 태스크가 없습니다" 안내

### 4-5. Footer
- "(c) 2026 TaskFlow. Built for high performance."

## 5. 개선 사항 반영 목록

| # | 항목 | 원본 | 변경 |
|---|------|------|------|
| 1 | 폰트 | Inter | Pretendard |
| 2 | 삭제 확인 | 즉시 삭제 | confirm 다이얼로그 |
| 3 | 데이터 영속성 | 없음 (시드만) | localStorage |
| 4 | 체크박스 터치 | w-6 h-6 | + p-2 래퍼 (44px) |
| 5 | 마일스톤 크기 | w-3 h-3, 10px | w-4 h-4, text-xs |
| 6 | Footer 연도 | 2023 | 2026 |

## 6. 컴포넌트 구조

```
src/app/
├── layout.tsx          # RootLayout (Pretendard 폰트, globals.css)
├── page.tsx            # 메인 대시보드 (Client Component)
├── globals.css         # Tailwind + 커스텀 애니메이션
└── favicon.ico
```

모든 로직은 page.tsx에 집중 (단일 페이지, 컴포넌트 분리는 2차에서).
