# Context: .claude 설정 배포 및 뷰어
> 생성일: 2026-03-11 | 최종 업데이트: 2026-03-11

## 프로젝트 스택
- Framework: Flutter 3.41.4 (Windows Desktop)
- Language: Dart 3.11.1
- UI Library: fluent_ui ^4.9.2 (Windows Fluent Design)
- State Management: flutter_riverpod ^2.6.1 (AsyncNotifier pattern)
- WebView: webview_windows ^0.4.0 (HTML 산출물 뷰어)
- Font: Pretendard (assets/fonts/, OTF, 400~800)
- Data Storage: 로컬 JSON 파일 (path_provider -> Documents/Devdock/)
- File Access: dart:io (로컬 파일 시스템 직접 접근)

## 디자인 시스템
- 컬러 팔레트:
  - Primary: Indigo (50~700), AccentColor로 FluentTheme에 적용
  - Background: #F8FAFC (light), #0F172A (dark)
  - Foreground: #1E293B (light), #F1F5F9 (dark)
  - Status: emerald(완료/승인), purple(진행중), blue(기획), red(반려), amber(대기)
- 타이포그래피: Pretendard (Regular 400 ~ ExtraBold 800)
- 간격 체계: EdgeInsets 기반, padding 12~32, gap 4~16
- 기존 UI 컴포넌트:
  - 시맨틱 컬러: AppSemanticColors (light/dark 구분, scaffoldBg/cardBg/sidebarBg/textPrimary 등)
  - 카드: 12px borderRadius, border 1px, hover 시 primary border + shadow
  - 모달: ContentDialog (fluent_ui), maxWidth 440
  - 버튼: FilledButton (primary), Button (secondary), GestureDetector 래핑 커스텀
  - 배지: StatusBadge (status bg/text 기반), 4px borderRadius
  - 사이드바: 220px(확장)/56px(축소), Row(Sidebar + Expanded(Content))
  - 네비게이션: _NavItem (icon + label, 12px borderRadius, active 시 primary 배경)

## 현재 .claude 폴더 구조 (마스터 템플릿)
```
.claude/
  README.md                    # 사용 설명서
  settings.json                # Claude 설정 (permissions 등)
  settings.local.json          # 개인 환경 설정 (배포 제외 대상)
  agents/
    product-team.md            # AI 에이전트 정의
  commands/
    init.md                    # /init 명령
    dev/
      ask.md                   # /dev:ask
      build.md                 # /dev:build
      go.md                    # /dev:go
    pm/
      pm.md                    # /pm:pm
      idea-template.html       # 기획 템플릿
    team/
      product.md               # /team:product
  hooks/
    slack-notify.js            # Slack 알림 훅
```

## 기존 화면 구조
- main.dart: AppShell = Row(Sidebar + Expanded(Content))
  - 대시보드: DashboardScreen (카드 그리드, 프로젝트 추가/삭제)
  - 상세: ProjectDetailScreen (좌측 태스크 목록 280px + 우측 WebView 뷰어)
- AddProjectDialog: ContentDialog, 프로젝트 이름/경로/컬러 입력, 폴더 선택(FilePicker)
- ProjectCard: 프로젝트 카드 (이름, 경로, 최근 활동, 태스크 목록)

## 관련 파일 경로
- 모델: flutter_app/lib/models/project.dart
- 서비스: flutter_app/lib/services/project_service.dart
- 프로바이더: flutter_app/lib/providers/project_providers.dart
- 대시보드: flutter_app/lib/screens/dashboard_screen.dart
- 상세: flutter_app/lib/screens/project_detail_screen.dart
- 프로젝트 추가 다이얼로그: flutter_app/lib/widgets/add_project_dialog.dart
- 테마: flutter_app/lib/theme/app_theme.dart
- 사이드바: flutter_app/lib/widgets/sidebar.dart

## 프론트엔드 컨텍스트
- 재사용 컴포넌트:
  - StatusBadge: `lib/widgets/status_badge.dart` (status prop, fontSize)
  - ProjectCard: `lib/widgets/project_card.dart` (project, history, onTap, onDelete)
  - AddProjectDialog: `lib/widgets/add_project_dialog.dart` (ContentDialog 기반)
  - AppSidebar: `lib/widgets/sidebar.dart` (currentIndex, onNavigate)
- 공통 유틸:
  - semanticColors(context): 현재 테마의 시맨틱 컬러 반환
  - AppColors.dotColor(name): 프로젝트 컬러 dot 반환
  - AppColors.statusBg/statusText: 상태별 배경/텍스트 색상
- 코딩 패턴:
  - ConsumerStatefulWidget + ConsumerState (Riverpod 연동 StatefulWidget)
  - ConsumerWidget (Riverpod 연동 StatelessWidget)
  - ref.watch() / ref.read() 패턴
  - AnimatedContainer for transitions (150~200ms)
  - GestureDetector + MouseRegion for interactive elements
  - WebView 파일 표시: 임시 HTML 파일 생성 → Uri.file → loadUrl
- 상태 관리:
  - AsyncNotifierProvider (목록), FutureProvider.family (개별 조회)
  - StateProvider (UI 상태: 테마, 필터, 사이드바, 선택 항목)
  - ref.invalidateSelf() / ref.invalidate() for refresh

## 금지 사항
- 기존 컴포넌트와 중복되는 새 컴포넌트 생성 금지
- 기존 컬러 팔레트/타이포 체계와 충돌하는 값 사용 금지
- CLAUDE.md에 명시된 스택 외 다른 프레임워크/라이브러리 임의 도입 금지
- 기존 Service -> Provider -> Screen 아키텍처 패턴 위반 금지
