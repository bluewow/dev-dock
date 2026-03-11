# Context: 사용자 가이드 도움말 화면
> 생성일: 2026-03-11 | 최종 업데이트: 2026-03-11

## 프로젝트 스택
- Framework: Flutter 3.41.4 (Windows Desktop)
- Styling: fluent_ui ^4.9.2, AppSemanticColors (시맨틱 토큰), AppColors (정적 팔레트)
- Architecture: Service → Provider → Screen/Widget (단방향)
- Font: Pretendard (400~800)

## 디자인 시스템
- 컬러 팔레트: Primary(Indigo 50~700), Slate, Emerald, Blue, Purple, Amber, Rose, Red, Cyan
- 타이포그래피: Pretendard / 24px w800(헤더), 15px w700(섹션), 13px w500(본문), 11px w700(라벨)
- 간격 체계: padding all(32) 페이지, 16/24 섹션, 12 카드 내부
- 기존 UI 컴포넌트: _NavItem (사이드바), ProjectCard (카드 그리드), StatusBadge, ContentDialog

## 프론트엔드 컨텍스트
- 재사용 컴포넌트:
  - AppSidebar: lib/widgets/sidebar.dart (_NavItem 패턴, currentIndex/onNavigate)
  - _CollapsedSidebar: lib/main.dart (56px 축소 사이드바)
  - semanticColors(context): lib/theme/app_theme.dart (AppSemanticColors 반환)
- 공통 Provider:
  - themeModeProvider: StateProvider<ThemeMode>
  - sidebarCollapsedProvider: StateProvider<bool>
- 스타일 토큰: AppSemanticColors.light/dark (scaffoldBg, cardBg, sidebarBg, textPrimary, textSecondary, textTertiary, border, hoverBg)
- 코딩 패턴: ConsumerWidget + ref.watch, GestureDetector + MouseRegion, AnimatedContainer

## 네비게이션 구조
- AppShell._navIndex: 0 = 대시보드 (현재 유일한 화면)
- 도움말 추가 시: 1 = 도움말 (HelpScreen)
- 사이드바 AppSidebar에 _NavItem 1개 추가
- AppShell에서 _navIndex == 1 일 때 HelpScreen 렌더

## 금지 사항
- 기존 컴포넌트와 중복되는 새 컴포넌트 생성 금지
- 기존 컬러 팔레트/타이포 체계와 충돌하는 값 사용 금지
- CLAUDE.md에 명시된 스택 외 다른 프레임워크/라이브러리 임의 도입 금지
- WebView 사용 금지 (순수 Flutter 위젯으로만 구성)
