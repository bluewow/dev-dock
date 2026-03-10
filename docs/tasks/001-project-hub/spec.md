# Project Hub - 구현 스펙

> 승인일: 2026-03-10
> 상태: 승인 완료

## 1. 개요

로컬 PC의 프로젝트들을 등록하고, docs/ 하위 HTML 산출물을 사이트 내에서 뷰어로 확인하며,
승인/반려 의사결정을 기록하는 프로젝트 관리 허브.

## 2. 기술 스택

- **Framework**: Next.js 16 (App Router)
- **Styling**: Tailwind CSS v4
- **Font**: Pretendard (CDN)
- **Language**: TypeScript
- **Data**: 서버 사이드 JSON 파일 (data/projects.json) + 각 프로젝트의 docs/history.json
- **File Access**: Next.js API Routes + Node.js fs 모듈

## 3. 데이터 모델

```typescript
// data/projects.json에 저장
interface Project {
  id: string;           // crypto.randomUUID() 기반
  name: string;
  path: string;         // 로컬 절대 경로
  color: string;        // tailwind color name (emerald, blue, purple, amber, rose, slate)
  createdAt: string;    // ISO 8601
  updatedAt: string;    // ISO 8601
}

// 각 프로젝트의 docs/history.json (읽기 전용)
interface TaskLog {
  phase: string;
  status: string;
  date: string;
  note: string;
}

interface TaskEntry {
  slug: string;
  name: string;
  logs: TaskLog[];
  reviews?: string[];
  spec?: string;
  id?: string;
  path?: string;
}

// 스캔 결과
interface ScannedFile {
  name: string;
  relativePath: string;
  type: "html" | "md" | "json" | "other";
  size: number;
  modifiedAt: string;
}

interface ScannedTask {
  slug: string;
  files: ScannedFile[];
  hasSpec: boolean;
}

interface ProjectScanResult {
  projectId: string;
  tasks: ScannedTask[];
  history: TaskEntry[] | null;
}
```

## 4. API 엔드포인트

### 4-1. GET /api/projects
- 프로젝트 목록 조회
- 응답: Project[]

### 4-2. POST /api/projects
- 프로젝트 등록
- Body: { name: string, path: string, color?: string }
- 검증: 경로 존재 여부, 중복 경로 방지
- 응답: Project

### 4-3. DELETE /api/projects/[id]
- 프로젝트 등록 해제 (파일 삭제 아님)
- 응답: { success: boolean }

### 4-4. GET /api/projects/[id]/scan
- docs/ 하위 산출물 스캔
- docs/tasks/ 하위 폴더 재귀 스캔 + docs/history.json 파싱
- 응답: ProjectScanResult

### 4-5. GET /api/projects/[id]/file?path=...
- HTML 파일 내용 반환 (iframe 서빙)
- 보안: docs/ 밖 경로 접근 차단 (path traversal 방지)
- Content-Type: text/html

### 4-6. POST /api/projects/[id]/decision
- 의사결정 기록
- Body: { taskSlug: string, decision: "승인"|"반려"|"조건부승인", note: string }
- 동작: 해당 프로젝트의 docs/history.json에 log 추가

### 4-7. GET /api/projects/[id]/validate
- 경로 유효성 확인
- 응답: { valid: boolean, hasDocs: boolean, message?: string }

## 5. 페이지 구조

```
src/app/
├── layout.tsx              # RootLayout (Pretendard, globals.css)
├── globals.css             # Tailwind + 커스텀 테마
├── page.tsx                # 메인 대시보드 (프로젝트 카드 그리드)
├── projects/
│   └── [id]/
│       └── page.tsx        # 프로젝트 상세 (태스크 목록 + 산출물 뷰어)
└── api/
    └── projects/
        ├── route.ts        # GET (목록), POST (등록)
        └── [id]/
            ├── route.ts    # DELETE (삭제)
            ├── scan/
            │   └── route.ts
            ├── file/
            │   └── route.ts
            ├── decision/
            │   └── route.ts
            └── validate/
                └── route.ts
```

## 6. UI 구성

### 6-1. 레이아웃
- 좌측 사이드바 (w-56, 접기 시 w-14)
- 사이드바: 로고, 대시보드/전체 프로젝트/최근활동 링크, 하단 설정
- 메인 콘텐츠 영역

### 6-2. 메인 대시보드 (/)
- 상단: "내 프로젝트" 제목 + 프로젝트 수 + "새 프로젝트" 버튼
- 프로젝트 카드 그리드 (1~3열 반응형)
- 카드 구성: 컬러 도트 + 이름, 상태 뱃지, 경로(mono), 진행률 바, 최근 활동
- 빈 카드: 점선 보더 + "새 프로젝트 추가"

### 6-3. 프로젝트 등록 모달
- 백드롭 블러 + 중앙 모달 (max-w-md)
- 필드: 프로젝트 이름, 로컬 경로 + 검증 버튼, 카드 컬러 선택 (6색)
- 검증 성공 시 초록 도트 + 메시지

### 6-4. 프로젝트 상세 (/projects/[id])
- 사이드바 접힌 상태 (아이콘만)
- 좌측 패널 (w-72): 프로젝트 헤더 + 태스크 목록
- 우측 패널 (flex-1): 산출물 뷰어 (iframe) + 상단 파일명 + 하단 의사결정 바
- 의사결정 바: 코멘트 입력 + 반려 버튼(red) + 승인 버튼(primary)

### 6-5. 디자인 토큰
- 기존 globals.css 테마 유지 (primary: indigo)
- 상태 컬러: emerald(활성/완료), blue(기획), amber(대기), purple(진행), slate(비활성)
- 카드: rounded-xl, border border-slate-200, hover:border-primary-300 hover:shadow-md
- 뱃지: text-xs, px-2 py-0.5, rounded-full, bg-{color}-50 text-{color}-700
- 버튼: rounded-xl, font-bold, transition-colors
- 트랜지션: 200ms (호버), 300ms (모달)

## 7. 보안

- path traversal 방지: file API에서 docs/ 하위만 허용
- 절대 경로 접근: 등록된 프로젝트의 경로만 허용
- 파일 쓰기: decision API만 history.json에 쓰기 허용
