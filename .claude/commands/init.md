---
description: 프로젝트 스캔 → CLAUDE.md 자동 생성/업데이트 (new: 신규 프로젝트 세팅)
---

당신은 프로젝트 분석 및 초기 세팅 전문가입니다. 기존 프로젝트를 스캔하거나, 새 프로젝트를 세팅하고 CLAUDE.md를 생성합니다.

## Step 0: 모드 판별

루트 디렉토리에서 빌드/설정 파일(package.json, pom.xml, go.mod 등) 또는 소스 코드 존재 여부를 확인합니다.

| 조건 | 판단 |
|:-----|:-----|
| 빌드 파일 또는 소스 코드가 존재 | **Mode A: 기존 프로젝트 분석** |
| 빈 디렉토리 또는 CLAUDE.md만 존재 | **Mode B: 신규 프로젝트 세팅** |
| 판단이 모호한 경우 | AskUserQuestion으로 확인 |

`$ARGUMENTS`에 `new` 또는 `신규`가 포함되면 무조건 **Mode B**로 진행합니다.

---

## Mode A: 기존 프로젝트 분석

### Step A1: 프로젝트 스캔

루트 및 1depth 서브 디렉토리에서 빌드/설정 파일을 탐색합니다:

| 파일 | 기술 스택 |
|:-----|:---------|
| package.json | Node.js (React, Vue, Next.js, Nuxt, Express 등) |
| pom.xml | Java (Spring Boot, Maven) |
| build.gradle(.kts) | Java/Kotlin (Spring Boot, Gradle) |
| requirements.txt / pyproject.toml | Python (Django, FastAPI, Flask 등) |
| go.mod | Go |
| Cargo.toml | Rust |
| composer.json | PHP (Laravel 등) |
| Gemfile | Ruby (Rails 등) |

**여러 프로젝트가 감지되면** 각 프로젝트를 개별 분석한 뒤, 하나의 CLAUDE.md에 통합합니다.

### Step A2: 구조 및 코드 분석

각 프로젝트(또는 단일 프로젝트)에 대해:
- 1~2 depth 폴더 구조 및 아키텍처 패턴 감지 (MVC, Clean Architecture 등)
- 주요 파일 5~10개를 읽고 코드 컨벤션, API 패턴, 상태관리, 에러처리, 테스트 패턴 파악
- 네이밍 컨벤션 파악 (파일명, 폴더명)

### Step A3: CLAUDE.md 생성

→ **CLAUDE.md 생성 규칙** 섹션 참조.

---

## Mode B: 신규 프로젝트 세팅

### Step B1: 프로젝트 정보 수집

AskUserQuestion으로 한 번에 최대 4개 질문을 묶어서 수집합니다.

#### 라운드 1

| 질문 | 선택지 |
|:-----|:-------|
| 프로젝트 유형 | 프론트엔드 / 백엔드 / 풀스택 |
| 프로젝트 이름 | "현재 폴더명 사용" / "직접 입력" |

#### 라운드 2 — 유형별 분기

**프론트엔드:**

| 질문 | 선택지 |
|:-----|:-------|
| 프레임워크 | Next.js / React (Vite) / Vue (Nuxt) / Vue (Vite) |
| 스타일링 | Tailwind CSS / styled-components / CSS Modules / SCSS |
| 패키지 매니저 | npm / yarn / pnpm / bun |

**백엔드:**

| 질문 | 선택지 |
|:-----|:-------|
| 프레임워크 | Express / NestJS / Spring Boot / FastAPI |
| 데이터베이스 | PostgreSQL / MySQL / MongoDB / SQLite |
| 패키지 매니저 | 프레임워크 언어에 맞게 자동 판별 |

**풀스택:**

| 질문 | 선택지 |
|:-----|:-------|
| 프론트 프레임워크 | Next.js / React (Vite) / Vue (Nuxt) / Vue (Vite) |
| 백엔드 프레임워크 | Express / NestJS / Spring Boot / FastAPI |
| 스타일링 | Tailwind CSS / styled-components / CSS Modules / SCSS |
| 데이터베이스 | PostgreSQL / MySQL / MongoDB / SQLite |

#### 라운드 3 — 공통

| 질문 | 선택지 |
|:-----|:-------|
| 추가 설정 (다중 선택) | TypeScript / ESLint+Prettier / Testing / Docker |

### Step B2: 프로젝트 스캐폴딩

#### 공식 CLI 우선 사용

| 프레임워크 | CLI 명령 |
|:-----------|:---------|
| Next.js | `npx create-next-app@latest` |
| React (Vite) | `npm create vite@latest` |
| Vue (Nuxt) | `npx nuxi@latest init` |
| Vue (Vite) | `npm create vite@latest` (vue 템플릿) |
| NestJS | `npx @nestjs/cli new` |
| Spring Boot | `spring init` 또는 Spring Initializr API |
| FastAPI / Express | 수동 구조 생성 |

CLI 실행 시 Step B1에서 수집한 옵션을 CLI 인자로 전달합니다.
CLI가 없는 경우 공식 문서 권장 구조에 따라 수동 생성합니다.

#### 추가 설정 적용

| 설정 | 적용 내용 |
|:-----|:---------|
| TypeScript | tsconfig.json 생성 (CLI가 미처리 시) |
| ESLint+Prettier | 설정 파일 생성 + 의존성 설치 |
| Testing | vitest/jest 설정 + 샘플 테스트 |
| Docker | Dockerfile, docker-compose.yml, .dockerignore |

### Step B3: CLAUDE.md 생성

스캐폴딩 완료 후, Step A1~A2 과정을 실행하여 실제 생성된 구조 기반으로 CLAUDE.md를 작성합니다.

---

## CLAUDE.md 생성 규칙

### 단일 프로젝트

```markdown
# [프로젝트명]

## Tech Stack
- Framework: [감지됨 또는 사용자 선택]
- Styling: [프론트엔드인 경우]
- Database: [감지된 경우 또는 사용자 선택]
- 기타 주요 라이브러리

## Project Structure
[1~2 depth 디렉토리 트리 + 각 폴더 역할 한줄 설명]

## Patterns & Conventions
[아키텍처 패턴, 네이밍 규칙, 파일 구조 규칙 — 테이블 형태 권장]

## Style Guide
[프론트엔드인 경우만: CSS Framework, Design Tokens 경로, 핵심 규칙]

## Dev Commands
[빌드, 개발서버, 테스트, 린트 명령어]
```

목표: 80~120줄.

### 멀티 프로젝트 (같은 폴더에 여러 프로젝트가 있는 경우)

하나의 루트 CLAUDE.md에 모든 프로젝트를 통합합니다.

```markdown
# [전체 프로젝트명]

## Overview
[전체 구성 한줄 요약]

## Projects

### [프로젝트A 폴더명] — [역할]
- **Stack**: [기술 스택]
- **Structure**: [핵심 디렉토리 요약]
- **Patterns**: [주요 컨벤션]
- **Commands**: [빌드/실행/테스트]

### [프로젝트B 폴더명] — [역할]
- **Stack**: [기술 스택]
- **Structure**: [핵심 디렉토리 요약]
- **Patterns**: [주요 컨벤션]
- **Commands**: [빌드/실행/테스트]

## Common Rules
[프로젝트 간 공통 컨벤션이 있는 경우]
```

목표: 프로젝트당 15~25줄, 전체 200줄 이내.

---

## Rules

- 감지되지 않는 항목은 추측하지 말 것
- Mode A에서는 코드 수정 금지 (CLAUDE.md 생성만)
- Mode A에서는 실제 코드에서 발견된 패턴만 기록
- Mode B에서는 사용자 선택값 + 프레임워크 공식 권장 패턴을 기록
- 코드 예시 블록 사용 금지 — 규칙/경로/패턴명으로 기술
- 기존 CLAUDE.md가 있으면 AskUserQuestion으로 덮어쓸지 확인
- 완료 후 생성된 CLAUDE.md 내용을 요약 출력

## Output

### Mode A

```
프로젝트 스캔 완료

감지된 스택: [기술 스택 요약]
프로젝트 수: [N개]
생성된 파일: CLAUDE.md (루트)

이제 /dev:plan, /dev:go 명령을 사용할 수 있습니다.
```

### Mode B

```
프로젝트 세팅 완료

프로젝트: [프로젝트명]
스택: [선택된 기술 스택 요약]
스캐폴딩: [생성된 주요 디렉토리/파일 목록]
생성된 파일: CLAUDE.md

이제 /dev:plan, /dev:go 명령을 사용할 수 있습니다.
```
