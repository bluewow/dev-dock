# Spec: .claude 설정 배포 및 뷰어

> 승인일: 2026-03-11 | 상태: 승인

## 개요

Devdock에서 프로젝트를 추가할 때 `.claude` 설정 폴더를 대상 프로젝트에 설치(복사)하는 기능.
프로젝트 상세 화면에서 설치된 `.claude` 파일을 읽기 전용으로 열람하는 뷰어.

---

## 1. 모델 변경

### 1.1 ClaudeFileEntry (신규 모델)

파일: `lib/models/claude_file_entry.dart`

```dart
class ClaudeFileEntry {
  final String name;
  final String relativePath;
  final String absolutePath;
  final bool isDirectory;
  final List<ClaudeFileEntry> children;

  const ClaudeFileEntry({
    required this.name,
    required this.relativePath,
    required this.absolutePath,
    required this.isDirectory,
    this.children = const [],
  });
}
```

### 1.2 ClaudeInstallResult (신규 모델)

파일: `lib/models/claude_install_result.dart`

```dart
class ClaudeInstallResult {
  final bool success;
  final int filesCopied;
  final String? error;
  final List<String> excludedFiles;

  const ClaudeInstallResult({
    required this.success,
    required this.filesCopied,
    this.error,
    this.excludedFiles = const [],
  });
}
```

---

## 2. 서비스 확장

파일: `lib/services/project_service.dart`에 메서드 추가

### 2.1 sourceClaudePath (getter)

Devdock 실행 파일 기준으로 프로젝트 루트의 `.claude` 경로를 반환.
- `Platform.resolvedExecutable` → 상위로 탐색하여 `.claude` 폴더 존재하는 루트를 찾음
- 개발 모드: `Platform.script` 또는 현재 작업 디렉토리 기반

### 2.2 hasClaudeConfig(String projectPath) → bool

`Directory(path.join(projectPath, '.claude')).existsSync()`

### 2.3 installClaude({required String targetPath, bool forceOverwrite = false}) → Future<ClaudeInstallResult>

1. 재귀 방지: `targetPath`가 Devdock 자체 경로와 같으면 에러 반환
2. 쓰기 권한 검증: 임시 파일 생성 시도
3. `forceOverwrite == true`이고 기존 `.claude` 존재 시: 기존 폴더 삭제
4. `forceOverwrite == false`이고 기존 `.claude` 존재 시: 에러 반환
5. 소스 `.claude` 폴더를 재귀적으로 복사
6. **제외 대상**: `settings.local.json`
7. 복사 완료 후 `ClaudeInstallResult` 반환

### 2.4 scanClaudeFiles(String projectPath) → List<ClaudeFileEntry>

`projectPath/.claude` 하위를 재귀 스캔하여 트리 구조 반환.
- 디렉토리는 `isDirectory: true`, children에 하위 항목
- 파일은 `isDirectory: false`, children 빈 리스트
- 알파벳순 정렬 (디렉토리 먼저)

### 2.5 readClaudeFile(String absolutePath) → String

`File(absolutePath).readAsStringSync()`로 내용 반환.
파일이 없으면 빈 문자열 반환.

---

## 3. Provider 추가

파일: `lib/providers/project_providers.dart`에 추가

```dart
// .claude 파일 트리 스캔
final claudeFilesProvider = FutureProvider.family<List<ClaudeFileEntry>, String>(
  (ref, projectId) async {
    ref.watch(scanTriggerProvider);
    final service = ref.read(projectServiceProvider);
    final project = await service.findProject(projectId);
    if (project == null) return [];
    return service.scanClaudeFiles(project.path);
  },
);

// .claude 섹션 접기/펼치기 상태
final claudeSectionExpandedProvider = StateProvider<bool>((ref) => true);
```

---

## 4. UI 변경

### 4.1 AddProjectDialog 수정

파일: `lib/widgets/add_project_dialog.dart`

**추가 상태:**
- `bool _installClaude = false` (토글 기본값 OFF)
- `bool? _hasExistingClaude` (경로 검증 시 감지)

**UI 변경:**
- 컬러 선택 아래에 `.claude 설치` 섹션 추가
- 경계선(`border`) + 아이콘 + 토글 스위치
- `_hasExistingClaude == true`이면 amber 경고 박스 표시
- 토글 ON 시 설치 항목 미리보기 (commands, agents, hooks, settings.json, README.md)
- `settings.local.json`은 취소선 + "제외" 표시

**경로 검증 확장:**
- `_validate()` 내에서 `service.hasClaudeConfig(path)` 호출하여 `_hasExistingClaude` 설정

**등록 로직 확장:**
- `_submit()` 내에서 프로젝트 추가 후:
  - `_installClaude == true`이면 `service.installClaude()` 호출
  - 기존 `.claude` 존재 시 `forceOverwrite: true`
  - 결과에 따라 성공/실패 메시지 표시
  - 성공 시 `settings.local.json` 가이드 InfoBar 표시

### 4.2 ProjectDetailScreen 수정

파일: `lib/screens/project_detail_screen.dart`

**좌측 패널 하단에 `.claude` 섹션 추가:**

1. 태스크 목록 `Expanded` 아래에 `.claude` 섹션 배치
2. 접기/펼치기 헤더 (GestureDetector + claudeSectionExpandedProvider)
3. 펼침 시:
   - `.claude` 존재: 파일 트리 표시 (재귀 렌더링)
   - `.claude` 미존재: "미설치" 안내 + "설치하기" 버튼
4. 파일 클릭 시:
   - `.claude` 파일 내용을 HTML로 변환하여 WebView에 로드
   - 코드 블록 스타일 (monospace, 읽기 전용)
   - 뷰어 헤더에 `.claude > 파일명` 브레드크럼 표시

**파일 내용 HTML 렌더링:**
- `_generateClaudeFileHtml(String content, String fileName, bool isDark)` 메서드
- Pretendard + monospace, 줄번호, 다크/라이트 대응
- 임시 파일로 저장하여 WebView에 로드 (기존 history HTML 패턴과 동일)

### 4.3 설치 확인 다이얼로그 (인라인)

기존 `.claude`가 있고 설치 토글 ON 시, 등록 버튼 클릭하면:
- ContentDialog로 최종 확인
- "기존 .claude 폴더를 삭제하고 새로 설치합니다. 계속하시겠습니까?"
- 확인/취소 버튼

---

## 5. 디자인 토큰

기존 AppColors, AppSemanticColors 사용. 신규 색상 없음.

| 요소 | 라이트 | 다크 |
|------|--------|------|
| .claude 섹션 배경 | scaffoldBg | scaffoldBg |
| 설치됨 배지 | emerald50/emerald700 | emerald400/0.15 |
| 미설치 배지 | slate100/slate500 | slate700/slate400 |
| 선택된 파일 | primary50 | primary500/0.1 |
| 경고 박스 | amber50/amber200 | amber400/0.15 |
| 토글 ON | primary500/primary600 | primary500 |
| 토글 OFF | slate300 | slate600 |

---

## 6. 엣지 케이스

1. **재귀 설치 방지**: Devdock 자체 경로 감지 → "Devdock 프로젝트에는 설치할 수 없습니다" 메시지
2. **쓰기 권한 없음**: 사전 체크 → "쓰기 권한이 없습니다" 에러
3. **소스 .claude 없음**: Devdock 프로젝트에 `.claude`가 없으면 설치 옵션 비활성화
4. **복사 중 실패**: 부분 복사 시 롤백 (생성된 파일 삭제)
5. **빈 .claude 폴더**: 파일이 하나도 없으면 "설정 파일 없음" 안내
