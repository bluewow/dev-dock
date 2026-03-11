# Spec: UI 개선 - 테마 일관성/다크모드/탭 구조/이력 뷰어
> 승인: 조건부승인 (2026-03-11)
> 조건: 태스크 목록에 상태 필터(전체/완료/진행중) 추가

## 조건 사항
- 프로젝트 상세화면의 태스크 목록에 상태 필터 버튼 추가
- 필터 옵션: 전체 / 완료 / 진행중
- 필터 UI는 태스크 헤더 영역(태스크 수 + 이력 버튼 사이)에 배치

---

## 1. 테마 시스템 (app_theme.dart)

### AppSemanticColors 클래스 추가

```dart
class AppSemanticColors {
  final Color scaffoldBg;
  final Color cardBg;
  final Color sidebarBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color borderSubtle;
  final Color hoverBg;

  const AppSemanticColors({
    required this.scaffoldBg,
    required this.cardBg,
    required this.sidebarBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.borderSubtle,
    required this.hoverBg,
  });

  static const light = AppSemanticColors(
    scaffoldBg: Color(0xFFF8FAFC),     // slate-50
    cardBg: Color(0xFFFFFFFF),          // white
    sidebarBg: Color(0xFFFFFFFF),       // white
    textPrimary: Color(0xFF1E293B),     // slate-800
    textSecondary: Color(0xFF64748B),   // slate-500
    textTertiary: Color(0xFF94A3B8),    // slate-400
    border: Color(0xFFE2E8F0),          // slate-200
    borderSubtle: Color(0xFFF1F5F9),    // slate-100
    hoverBg: Color(0xFFF1F5F9),         // slate-100
  );

  static const dark = AppSemanticColors(
    scaffoldBg: Color(0xFF0F172A),      // slate-900
    cardBg: Color(0xFF1E293B),          // slate-800
    sidebarBg: Color(0xFF0F172A),       // slate-900
    textPrimary: Color(0xFFF1F5F9),     // slate-100
    textSecondary: Color(0xFF94A3B8),   // slate-400
    textTertiary: Color(0xFF64748B),    // slate-500
    border: Color(0xFF334155),          // slate-700
    borderSubtle: Color(0xFF1E293B),    // slate-800
    hoverBg: Color(0xFF334155),         // slate-700
  );
}
```

### AppColors 추가 상수
```dart
// 다크 모드용 Indigo
static const primary400 = Color(0xFF818CF8);  // indigo-400 (다크 모드 액센트)

// 다크 모드용 slate
static const slate900 = Color(0xFF0F172A);
```

### buildAppTheme() / buildDarkTheme()
- `buildAppTheme()`: 기존 유지, typography에 textPrimary 색상 적용
- `buildDarkTheme()`: 다크 팔레트 적용, brightness: Brightness.dark
- 다크 모드에서 accentColor는 primary500 사용 (라이트는 primary600 유지)

### semanticColors() 헬퍼
```dart
AppSemanticColors semanticColors(BuildContext context) {
  return FluentTheme.of(context).brightness == Brightness.dark
      ? AppSemanticColors.dark
      : AppSemanticColors.light;
}
```

---

## 2. Provider 변경 (project_providers.dart)

### 추가할 Provider
```dart
// 테마 모드 Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// 태스크 필터 Provider
final taskFilterProvider = StateProvider<String>((ref) => '전체');
```

---

## 3. 메인 앱 변경 (main.dart)

### FluentApp 변경
```dart
class DevdockApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return FluentApp(
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      ...
    );
  }
}
```

### _CollapsedSidebar 변경
- Colors.white → semanticColors(context).sidebarBg
- AppColors.slate200 border → semanticColors(context).border

---

## 4. 사이드바 변경 (sidebar.dart)

### 테마 토글 버튼 추가
- 위치: 접기 버튼 위, Divider 아래
- 아이콘: 라이트 시 달(moon) → FluentIcons.clear_night, 다크 시 해(sun) → FluentIcons.sunny
- 동작: themeModeProvider.notifier 토글

### 하드코딩 색상 교체
- `Colors.white` → `semanticColors(context).sidebarBg`
- `AppColors.slate200` border → `semanticColors(context).border`

---

## 5. 프로젝트 상세화면 변경 (project_detail_screen.dart)

### 탭 구조 제거
- `_activeTab` 상태 변수 제거
- `_TabButton` 위젯 제거
- 탭 바 UI 제거
- `_buildArtifactsList()` 메서드 제거
- `_buildHistoryList()` 메서드 제거

### 태스크 헤더 영역 교체
기존 탭 바 자리에:
```
[태스크 (N)] [전체|완료|진행중] [이력 버튼]
```
- 좌측: 태스크 수 텍스트
- 중앙: 상태 필터 칩 (전체/완료/진행중) - taskFilterProvider 연결
- 우측: 이력 버튼 (클릭 시 이력 HTML을 WebView에 로드)

### 상태 필터 동작
- `전체`: 모든 태스크 표시
- `완료`: lastStatus가 '완료' 또는 '승인'인 태스크만
- `진행중`: lastStatus가 '진행중', '기획', '대기' 등 완료/승인 이외인 태스크만

### 태스크 카드 강화
- description 추가: history의 name 필드 표시 (slug 아래)
- 진행 단계 인디케이터: 4개 pill (기획/디자인/승인/개발), 완료 단계는 emerald-400, 미완료는 border 색상
- 파일 칩에 아이콘 추가 (FluentIcons.document)

### 이력 버튼 동작
- 클릭 시 `_showHistory()` 호출
- ProjectService.generateHistoryHtml() 호출하여 HTML 문자열 생성
- 임시 HTML 파일 생성 후 WebView에 loadUrl

### 하드코딩 색상 교체
- Colors.white → semanticColors(context).cardBg
- AppColors.slate200 → semanticColors(context).border
- AppColors.slate50 → semanticColors(context).scaffoldBg
- 텍스트 색상: textPrimary / textSecondary / textTertiary

---

## 6. 대시보드 변경 (dashboard_screen.dart)

### 하드코딩 색상 교체
- 추가 카드(dashed border)의 Colors.transparent → semanticColors 대응
- 텍스트 색상 통일

---

## 7. 프로젝트 카드 변경 (project_card.dart)

### 하드코딩 색상 교체
- `Colors.white` → semanticColors(context).cardBg
- `Colors.black.withValues(alpha: ...)` → 다크 모드 대응 그림자
- `_StatusBadge` 다크 모드: 배경에 withOpacity(0.15) 적용

---

## 8. 다이얼로그 변경 (add_project_dialog.dart)

### 하드코딩 색상 교체
- 모달 내 텍스트 색상 통일

---

## 9. 이력 HTML 생성 (project_service.dart)

### generateHistoryHtml() 메서드 추가
```dart
String generateHistoryHtml(List<TaskEntry> history, {bool isDark = false})
```

- 입력: TaskEntry 리스트, 다크 모드 여부
- 출력: Tailwind CDN + Pretendard 포함한 완전한 HTML 문자열
- 레이아웃: 세로 타임라인, 각 태스크별 카드
- 각 태스크 카드 내: name, lastStatus 배지, phase별 색상 칩, note
- 다크/라이트 CSS 변수 분기

### 엣지 케이스
- history가 null 또는 빈 리스트: "이력이 없습니다" 메시지 HTML 반환
- note가 빈 문자열: note 영역 미표시

---

## 10. 상태 배지 변경 (status_badge.dart)

### 다크 모드 대응
- AppColors.statusBg(): 다크 모드에서 rgba 투명 배경 사용
- 현재 statusBg/statusText는 라이트 기준이므로, 다크 모드에서는 투명도 조절 방식 적용
- statusBgDark() / statusTextDark() 추가 또는 brightness 파라미터 추가

---

## 영향 파일 목록

| 파일 | 변경 |
|------|------|
| app_theme.dart | AppSemanticColors 추가, buildDarkTheme() 추가, semanticColors() 헬퍼 |
| project_providers.dart | themeModeProvider, taskFilterProvider 추가 |
| main.dart | ConsumerWidget 전환, darkTheme/themeMode 연결, _CollapsedSidebar 색상 교체 |
| sidebar.dart | 테마 토글 버튼, 하드코딩 색상 교체 |
| project_detail_screen.dart | 탭 제거, 필터 UI, 이력 버튼, 태스크 카드 강화, 색상 교체 |
| dashboard_screen.dart | 색상 교체 |
| project_card.dart | 색상 교체, 다크 모드 그림자 |
| add_project_dialog.dart | 색상 교체 |
| status_badge.dart | 다크 모드 대응 |
| project_service.dart | generateHistoryHtml() 추가 |
