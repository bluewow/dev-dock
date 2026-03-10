# Context: UI 개선 (테마/탭 구조/이력 뷰어)
> 생성일: 2026-03-10 | 최종 업데이트: 2026-03-10

## 프로젝트 스택
- Framework: Flutter 3.41.4 (Windows Desktop)
- Language: Dart 3.11.1
- UI Library: fluent_ui ^4.9.2 (Windows Fluent Design)
- State Management: flutter_riverpod ^2.6.1 (AsyncNotifier pattern)
- WebView: webview_windows ^0.4.0 (HTML 산출물 뷰어)
- Font: Pretendard (assets/fonts/, OTF, 400~800)
- Data Storage: 로컬 JSON 파일 (path_provider -> Documents/Devdock/)

## 디자인 시스템 (현재)
- 컬러 팔레트:
  - Primary: Indigo (50:#EEF2FF, 100:#E0E7FF, 200:#C7D2FE, 500:#6366F1, 600:#4F46E5, 700:#4338CA)
  - Background: #F8FAFC (slate-50)
  - Foreground: #1E293B (slate-800)
  - Slate: 50~800 (8단계)
  - Status: emerald(완료/승인), purple(진행중), blue(기획), red/rose(반려), amber(대기)
- 타이포그래피: Pretendard, Regular(400) ~ ExtraBold(800)
- 간격 체계: 4/8/12/16/20/24/32px (일관성 낮음, 하드코딩)
- 기존 UI 컴포넌트:
  - ProjectCard: 카드 (white bg, slate-200 border, 12px radius, hover 효과)
  - StatusBadge: 상태 배지 (배경+텍스트 색상 매핑)
  - AppSidebar: 좌측 네비게이션 (white bg, 접기/펼치기)
  - _CollapsedSidebar: 상세화면용 축소 사이드바
  - AddProjectDialog: ContentDialog 기반 모달
  - _TabButton: 상세화면 탭 버튼

## 현재 문제점 분석

### 1. 색상 일관성 문제
- `buildAppTheme()`에서 typography 색상을 별도 오버라이드하지 않음 -> fluent_ui 기본 black 적용
- 프로젝트 상세화면 `project.name` TextStyle에 color 미지정 (line 185)
- `Colors.white` 하드코딩 (sidebar, card, dialog 등 전역적으로 사용)
- 다크 테마 미지원

### 2. 산출물 탭 중복
- 태스크 탭: 태스크별 파일 목록 포함 (files Wrap)
- 산출물 탭: 모든 태스크의 파일을 평면 리스트로 중복 표시
- 기능적 중복 -> 산출물 탭 제거 권장

### 3. 이력 탭 한계
- 좌측 패널 내 텍스트 리스트 (280px 폭 제한)
- 타임라인/시각화 불가, 가독성 낮음
- WebView 뷰어가 있으므로 이력 HTML 렌더링이 가능

### 4. 테마 체계
- FluentThemeData: fontFamily, accentColor, scaffoldBgColor, brightness만 설정
- 카드/사이드바/뷰어 등에서 Colors.white 하드코딩
- 다크 모드 토글 없음
- typography 색상 체계 미설정

## 파일 경로 참조
- 테마: flutter_app/lib/theme/app_theme.dart
- 메인: flutter_app/lib/main.dart
- 대시보드: flutter_app/lib/screens/dashboard_screen.dart
- 상세화면: flutter_app/lib/screens/project_detail_screen.dart
- 사이드바: flutter_app/lib/widgets/sidebar.dart
- 프로젝트 카드: flutter_app/lib/widgets/project_card.dart
- 다이얼로그: flutter_app/lib/widgets/add_project_dialog.dart
- 상태 배지: flutter_app/lib/widgets/status_badge.dart
- 프로바이더: flutter_app/lib/providers/project_providers.dart
- 서비스: flutter_app/lib/services/project_service.dart
- 모델: flutter_app/lib/models/ (project.dart, task_entry.dart, scanned_file.dart)

## 금지 사항
- 기존 컴포넌트와 중복되는 새 컴포넌트 생성 금지
- 기존 Indigo 컬러 팔레트 체계 변경 금지 (다크 모드용 추가는 가능)
- 기존 API/서비스 네이밍 컨벤션 변경 금지
- CLAUDE.md에 명시된 스택 외 프레임워크/라이브러리 임의 도입 금지
- 기존 데이터 모델 구조 변경 금지 (확장은 가능)
