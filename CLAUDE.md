# Devdock - Local Project Management Hub

## Tech Stack
- **Framework**: Flutter 3.41.4 (Windows Desktop)
- **Language**: Dart 3.11.1
- **UI Library**: fluent_ui ^4.9.2 (Windows Fluent Design)
- **State Management**: flutter_riverpod ^2.6.1 (AsyncNotifier pattern)
- **WebView**: webview_windows ^0.4.0 (HTML 산출물 뷰어)
- **Font**: Pretendard (assets/fonts/, OTF, 400~800)
- **Data Storage**: 로컬 JSON 파일 (path_provider → Documents/Devdock/)
- **File Access**: dart:io (로컬 파일 시스템 직접 접근)

## Project Structure
```
flutter_app/
  lib/
    main.dart              # 앱 진입점, AppShell (사이드바 + 네비게이션)
    models/
      project.dart         # Project 데이터 모델 (CRUD, JSON 직렬화)
      scanned_file.dart    # ScannedFile, ScannedTask 모델
      task_entry.dart      # TaskEntry, TaskLog 모델
    providers/
      project_providers.dart  # Riverpod providers (projects, scan, viewer state)
    screens/
      dashboard_screen.dart   # 메인 대시보드 (카드 그리드)
      project_detail_screen.dart  # 프로젝트 상세 (태스크 목록 + WebView 뷰어)
    services/
      project_service.dart  # 비즈니스 로직 (CRUD, 경로 검증, 스캔, 의사결정)
    theme/
      app_theme.dart        # 디자인 토큰 (AppColors, FluentThemeData)
    widgets/
      add_project_dialog.dart  # 프로젝트 등록 모달
      project_card.dart     # 프로젝트 카드 위젯
      sidebar.dart          # 좌측 사이드바
      status_badge.dart     # 상태 배지 위젯
  assets/fonts/             # Pretendard OTF 폰트 파일
  windows/                  # Windows 네이티브 설정
docs/
  tasks/                    # 태스크별 산출물 (plan.html, design.html, spec.md)
  history.json              # 태스크 이력 로그
```

## Patterns & Conventions

| 항목 | 규칙 |
|------|------|
| 아키텍처 | Service → Provider → Screen/Widget (단방향) |
| 상태관리 | AsyncNotifier + FutureProvider.family (Riverpod) |
| 모델 | fromJson/toJson 수동 구현, copyWith 지원 |
| 네이밍 | snake_case (파일), PascalCase (클래스), camelCase (변수) |
| UI 구성 | fluent_ui 위젯 기반, AppColors 정적 상수로 색상 관리 |
| 산출물 스캔 | docs/tasks/{slug}/ 하위 HTML/MD 파일 자동 감지 |
| 의사결정 | history.json의 logs 배열에 승인/반려 기록 추가 |
| 경로 처리 | path 패키지 사용, 백슬래시→슬래시 정규화 |
| 레이아웃 | Row(Sidebar + Expanded(Content)), 상세 시 축소 사이드바 |

## Style Guide
- **Primary**: Indigo (50~700), AccentColor로 FluentTheme에 적용
- **Background**: #F8FAFC (slate-50)
- **Foreground**: #1E293B (slate-800)
- **Status Colors**: emerald(완료/승인), purple(진행중), blue(기획), red(반려), amber(대기)
- **Font Family**: Pretendard (Regular 400 ~ ExtraBold 800)
- **Language**: Korean (UI 라벨), 코드 주석은 한국어/영어 혼용

## Dev Commands
```bash
cd flutter_app
flutter run -d windows          # 개발 실행
flutter build windows           # 릴리즈 빌드
flutter analyze                 # 코드 분석
flutter test                    # 테스트 실행
```

## Git
- Commit messages in Korean, conventional style
- Co-Authored-By header required
