import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import '../models/task_entry.dart';
import '../models/scanned_file.dart';
import '../models/claude_file_entry.dart';
import '../models/claude_install_result.dart';

class ProjectService {
  static const _uuid = Uuid();
  String? _dataDir;

  Future<String> get dataDir async {
    if (_dataDir != null) return _dataDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _dataDir = p.join(appDir.path, 'Devdock');
    final dir = Directory(_dataDir!);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _dataDir!;
  }

  Future<File> get _projectsFile async {
    final dir = await dataDir;
    final file = File(p.join(dir, 'projects.json'));
    if (!file.existsSync()) {
      file.writeAsStringSync('[]');
    }
    return file;
  }

  // ─── Projects CRUD ──────────────────────────────────────────────────

  Future<List<Project>> getProjects() async {
    final file = await _projectsFile;
    try {
      final raw = file.readAsStringSync();
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Project.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveProjects(List<Project> projects) async {
    final file = await _projectsFile;
    final json = jsonEncode(projects.map((e) => e.toJson()).toList());
    file.writeAsStringSync(json);
  }

  Future<Project> addProject({
    required String name,
    required String path,
    String color = 'emerald',
  }) async {
    final projects = await getProjects();

    // 중복 경로 방지
    final normalized = path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    final duplicate = projects.any(
      (p) => p.path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '') == normalized,
    );
    if (duplicate) throw Exception('이미 등록된 경로입니다.');

    if (!Directory(path).existsSync()) {
      throw Exception('해당 경로가 존재하지 않습니다.');
    }

    final now = DateTime.now();
    final project = Project(
      id: _uuid.v4(),
      name: name.trim(),
      path: path,
      color: color,
      createdAt: now,
      updatedAt: now,
    );

    projects.add(project);
    await _saveProjects(projects);
    return project;
  }

  Future<void> deleteProject(String id) async {
    final projects = await getProjects();
    projects.removeWhere((p) => p.id == id);
    await _saveProjects(projects);
  }

  Future<Project?> findProject(String id) async {
    final projects = await getProjects();
    try {
      return projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Path Validation ─────────────────────────────────────────────────

  ({bool valid, bool hasDocs, String message}) validatePath(String path) {
    if (!Directory(path).existsSync()) {
      return (valid: false, hasDocs: false, message: '해당 경로가 존재하지 않습니다.');
    }

    final stat = FileStat.statSync(path);
    if (stat.type != FileSystemEntityType.directory) {
      return (valid: false, hasDocs: false, message: '경로가 디렉토리가 아닙니다.');
    }

    final docsDir = Directory(p.join(path, 'docs'));
    final hasDocs = docsDir.existsSync();

    return (
      valid: true,
      hasDocs: hasDocs,
      message: hasDocs
          ? '경로 확인됨 - docs/ 폴더 발견'
          : '경로 확인됨 - docs/ 폴더 없음 (산출물 없이 등록 가능)',
    );
  }

  // ─── Scan ─────────────────────────────────────────────────────────────

  Future<({List<ScannedTask> tasks, List<TaskEntry>? history})> scanProject(
    String projectPath,
  ) async {
    final docsDir = Directory(p.join(projectPath, 'docs'));
    List<TaskEntry>? history;

    // Read history.json
    final historyFile = File(p.join(docsDir.path, 'history.json'));
    if (historyFile.existsSync()) {
      try {
        final raw = historyFile.readAsStringSync();
        final list = jsonDecode(raw) as List<dynamic>;
        history = list.map((e) => TaskEntry.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        history = null;
      }
    }

    // Scan docs/tasks/
    final tasks = <ScannedTask>[];
    final tasksDir = Directory(p.join(docsDir.path, 'tasks'));

    if (tasksDir.existsSync()) {
      final taskFolders = tasksDir
          .listSync()
          .whereType<Directory>()
          .toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      final versionPattern = RegExp(r'^(.+)-v(\d+)(\..+)$');

      for (final folder in taskFolders) {
        final allFiles = <ScannedFile>[];
        var hasSpec = false;

        final entries = folder.listSync().whereType<File>().toList();
        for (final entry in entries) {
          final name = p.basename(entry.path);
          final stat = entry.statSync();
          final ext = p.extension(name).toLowerCase();

          String type;
          if (ext == '.html' || ext == '.htm') {
            type = 'html';
          } else if (ext == '.md') {
            type = 'md';
          } else if (ext == '.json') {
            type = 'json';
          } else {
            type = 'other';
          }

          if (name == 'spec.md') hasSpec = true;

          final relativePath = p.relative(entry.path, from: projectPath).replaceAll('\\', '/');
          allFiles.add(ScannedFile(
            name: name,
            relativePath: relativePath,
            absolutePath: entry.path,
            type: type,
            size: stat.size,
            modifiedAt: stat.modified,
          ));
        }

        // 버전 파일(idea-v1.html 등)을 베이스 파일에 그룹핑
        final versionFilesByBase = <String, List<ScannedFile>>{};
        final mainFiles = <ScannedFile>[];

        for (final file in allFiles) {
          final match = versionPattern.firstMatch(file.name);
          if (match != null) {
            final baseName = '${match.group(1)}${match.group(3)}';
            versionFilesByBase.putIfAbsent(baseName, () => []).add(file);
          } else {
            mainFiles.add(file);
          }
        }

        final groupedFiles = mainFiles.map((f) {
          final vers = List<ScannedFile>.from(versionFilesByBase[f.name] ?? []);
          vers.sort((a, b) {
            final aNum = int.tryParse(versionPattern.firstMatch(a.name)?.group(2) ?? '0') ?? 0;
            final bNum = int.tryParse(versionPattern.firstMatch(b.name)?.group(2) ?? '0') ?? 0;
            return aNum.compareTo(bNum);
          });
          return ScannedFile(
            name: f.name,
            relativePath: f.relativePath,
            absolutePath: f.absolutePath,
            type: f.type,
            size: f.size,
            modifiedAt: f.modifiedAt,
            versions: vers,
          );
        }).toList();

        tasks.add(ScannedTask(
          slug: p.basename(folder.path),
          files: groupedFiles,
          hasSpec: hasSpec,
        ));
      }
    }

    // Scan legacy docs/reviews/ if no tasks found
    if (tasks.isEmpty) {
      final reviewsDir = Directory(p.join(docsDir.path, 'reviews'));
      if (reviewsDir.existsSync()) {
        final files = <ScannedFile>[];
        var hasSpec = false;

        for (final entry in reviewsDir.listSync().whereType<File>()) {
          final name = p.basename(entry.path);
          final stat = entry.statSync();
          final ext = p.extension(name).toLowerCase();
          String type;
          if (ext == '.html' || ext == '.htm') {
            type = 'html';
          } else if (ext == '.md') {
            type = 'md';
          } else if (ext == '.json') {
            type = 'json';
          } else {
            type = 'other';
          }

          final relativePath = p.relative(entry.path, from: projectPath).replaceAll('\\', '/');
          files.add(ScannedFile(
            name: name,
            relativePath: relativePath,
            absolutePath: entry.path,
            type: type,
            size: stat.size,
            modifiedAt: stat.modified,
          ));
        }

        // Check specs
        final specsDir = Directory(p.join(docsDir.path, 'specs'));
        if (specsDir.existsSync()) {
          hasSpec = specsDir.listSync().any((e) => p.extension(e.path) == '.md');
          for (final entry in specsDir.listSync().whereType<File>()) {
            final name = p.basename(entry.path);
            final stat = entry.statSync();
            final relativePath = p.relative(entry.path, from: projectPath).replaceAll('\\', '/');
            files.add(ScannedFile(
              name: name,
              relativePath: relativePath,
              absolutePath: entry.path,
              type: 'md',
              size: stat.size,
              modifiedAt: stat.modified,
            ));
          }
        }

        if (files.isNotEmpty) {
          tasks.add(ScannedTask(slug: 'legacy', files: files, hasSpec: hasSpec));
        }
      }
    }

    return (tasks: tasks, history: history);
  }

  // ─── Decision ─────────────────────────────────────────────────────────

  Future<void> addDecision({
    required String projectPath,
    required String taskSlug,
    required String decision,
    String note = '',
  }) async {
    final historyFile = File(p.join(projectPath, 'docs', 'history.json'));
    if (!historyFile.existsSync()) {
      throw Exception('history.json이 존재하지 않습니다.');
    }

    final raw = historyFile.readAsStringSync();
    final list = jsonDecode(raw) as List<dynamic>;
    final history = list.map((e) => e as Map<String, dynamic>).toList();

    // Find task
    final taskIndex = history.indexWhere(
      (t) => t['slug'] == taskSlug || t['id'] == taskSlug,
    );

    if (taskIndex == -1) throw Exception('태스크를 찾을 수 없습니다.');

    final today = DateTime.now().toIso8601String().split('T')[0];
    final logs = (history[taskIndex]['logs'] as List<dynamic>?) ?? [];
    logs.add({
      'phase': '승인',
      'status': decision,
      'date': today,
      'note': note,
    });
    history[taskIndex]['logs'] = logs;

    historyFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(history),
    );
  }

  // ─── Claude Config ──────────────────────────────────────────────────

  /// Devdock 자체 .claude 폴더 경로를 반환한다.
  /// 실행 파일 기준으로 상위 디렉토리를 탐색하여 .claude 폴더가 있는 루트를 찾는다.
  String get sourceClaudePath {
    // 개발 모드: 현재 작업 디렉토리 기반
    var current = Directory.current.path;
    // .claude 폴더를 찾을 때까지 상위로 탐색 (최대 5단계)
    for (var i = 0; i < 5; i++) {
      final claudeDir = Directory(p.join(current, '.claude'));
      if (claudeDir.existsSync()) {
        return claudeDir.path;
      }
      final parent = p.dirname(current);
      if (parent == current) break; // 루트 도달
      current = parent;
    }

    // 릴리즈 모드: 실행 파일 기준 탐색
    final exePath = Platform.resolvedExecutable;
    current = p.dirname(exePath);
    for (var i = 0; i < 5; i++) {
      final claudeDir = Directory(p.join(current, '.claude'));
      if (claudeDir.existsSync()) {
        return claudeDir.path;
      }
      final parent = p.dirname(current);
      if (parent == current) break;
      current = parent;
    }

    return ''; // 찾지 못한 경우
  }

  /// 소스 .claude 폴더가 사용 가능한지 확인
  bool get hasSourceClaude => sourceClaudePath.isNotEmpty;

  /// 대상 프로젝트에 .claude 폴더가 존재하는지 확인
  bool hasClaudeConfig(String projectPath) {
    return Directory(p.join(projectPath, '.claude')).existsSync();
  }

  /// 대상 경로가 Devdock 자체 경로인지 확인 (재귀 방지)
  bool isDevdockPath(String targetPath) {
    final normalizedTarget = targetPath.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    final sourcePath = sourceClaudePath;
    if (sourcePath.isEmpty) return false;
    // .claude의 부모 디렉토리가 Devdock 루트
    final devdockRoot = p.dirname(sourcePath).replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    return normalizedTarget == devdockRoot;
  }

  /// .claude 설정을 대상 프로젝트에 설치 (복사)
  /// settings.local.json은 제외한다.
  Future<ClaudeInstallResult> installClaude({
    required String targetPath,
    bool forceOverwrite = false,
  }) async {
    // 1. 재귀 방지
    if (isDevdockPath(targetPath)) {
      return const ClaudeInstallResult(
        success: false,
        filesCopied: 0,
        error: 'Devdock 프로젝트에는 설치할 수 없습니다.',
      );
    }

    // 2. 소스 확인
    final source = sourceClaudePath;
    if (source.isEmpty) {
      return const ClaudeInstallResult(
        success: false,
        filesCopied: 0,
        error: 'Devdock .claude 소스를 찾을 수 없습니다.',
      );
    }

    // 3. 쓰기 권한 검증
    try {
      final testFile = File(p.join(targetPath, '.devdock_write_test'));
      testFile.writeAsStringSync('test');
      testFile.deleteSync();
    } catch (_) {
      return const ClaudeInstallResult(
        success: false,
        filesCopied: 0,
        error: '대상 경로에 쓰기 권한이 없습니다.',
      );
    }

    final targetClaudeDir = Directory(p.join(targetPath, '.claude'));

    // 4. 기존 .claude 처리
    if (targetClaudeDir.existsSync()) {
      if (!forceOverwrite) {
        return const ClaudeInstallResult(
          success: false,
          filesCopied: 0,
          error: '기존 .claude 폴더가 존재합니다. 덮어쓰기를 허용하세요.',
        );
      }
      // 기존 폴더 삭제
      try {
        targetClaudeDir.deleteSync(recursive: true);
      } catch (e) {
        return ClaudeInstallResult(
          success: false,
          filesCopied: 0,
          error: '기존 .claude 폴더 삭제 실패: $e',
        );
      }
    }

    // 5. 복사
    const excludeFiles = ['settings.local.json'];
    var filesCopied = 0;
    final copiedPaths = <String>[];

    try {
      filesCopied = _copyDirectoryRecursive(
        Directory(source),
        targetClaudeDir,
        excludeFiles,
        copiedPaths,
      );
    } catch (e) {
      // 부분 복사 롤백
      if (targetClaudeDir.existsSync()) {
        try {
          targetClaudeDir.deleteSync(recursive: true);
        } catch (_) {}
      }
      return ClaudeInstallResult(
        success: false,
        filesCopied: 0,
        error: '파일 복사 실패: $e',
      );
    }

    return ClaudeInstallResult(
      success: true,
      filesCopied: filesCopied,
      excludedFiles: excludeFiles,
    );
  }

  /// 디렉토리를 재귀적으로 복사한다. 제외 파일은 건너뛴다.
  int _copyDirectoryRecursive(
    Directory source,
    Directory target,
    List<String> excludeFiles,
    List<String> copiedPaths,
  ) {
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }

    var count = 0;
    for (final entity in source.listSync()) {
      final name = p.basename(entity.path);

      if (entity is File) {
        if (excludeFiles.contains(name)) continue;
        final targetFile = File(p.join(target.path, name));
        entity.copySync(targetFile.path);
        copiedPaths.add(targetFile.path);
        count++;
      } else if (entity is Directory) {
        final targetSubDir = Directory(p.join(target.path, name));
        count += _copyDirectoryRecursive(entity, targetSubDir, excludeFiles, copiedPaths);
      }
    }

    return count;
  }

  /// .claude 파일 트리를 스캔하여 반환한다.
  List<ClaudeFileEntry> scanClaudeFiles(String projectPath) {
    final claudeDir = Directory(p.join(projectPath, '.claude'));
    if (!claudeDir.existsSync()) return [];
    return _scanDirectory(claudeDir, projectPath);
  }

  /// 디렉토리를 재귀 스캔하여 ClaudeFileEntry 트리를 생성한다.
  List<ClaudeFileEntry> _scanDirectory(Directory dir, String basePath) {
    final entries = <ClaudeFileEntry>[];

    final items = dir.listSync()..sort((a, b) {
      // 디렉토리 먼저, 그 다음 알파벳순
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;
      if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
      return p.basename(a.path).compareTo(p.basename(b.path));
    });

    for (final item in items) {
      final name = p.basename(item.path);
      final relativePath = p.relative(item.path, from: basePath).replaceAll('\\', '/');

      if (item is Directory) {
        final children = _scanDirectory(item, basePath);
        entries.add(ClaudeFileEntry(
          name: name,
          relativePath: relativePath,
          absolutePath: item.path,
          isDirectory: true,
          children: children,
        ));
      } else if (item is File) {
        entries.add(ClaudeFileEntry(
          name: name,
          relativePath: relativePath,
          absolutePath: item.path,
          isDirectory: false,
        ));
      }
    }

    return entries;
  }

  /// .claude 파일 내용을 읽어 반환한다.
  String readClaudeFile(String absolutePath) {
    try {
      return File(absolutePath).readAsStringSync();
    } catch (_) {
      return '';
    }
  }

  /// .claude 파일 내용을 읽기 전용 HTML로 렌더링한다.
  String generateClaudeFileHtml(String content, String fileName, {bool isDark = false}) {
    final bg = isDark ? '#0F172A' : '#F8FAFC';
    final textPrimary = isDark ? '#F1F5F9' : '#1E293B';
    final textSecondary = isDark ? '#94A3B8' : '#64748B';
    final border = isDark ? '#334155' : '#E2E8F0';
    final lineNumColor = isDark ? '#475569' : '#CBD5E1';
    final headerBg = isDark ? '#1E293B' : '#F1F5F9';

    final escaped = _escapeHtml(content);
    final lines = escaped.split('\n');

    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="ko"><head><meta charset="UTF-8">');
    buffer.writeln('<style>');
    buffer.writeln('* { font-family: "Pretendard", -apple-system, sans-serif; margin: 0; padding: 0; box-sizing: border-box; }');
    buffer.writeln('body { background: $bg; color: $textPrimary; }');
    buffer.writeln('.header { background: $headerBg; border-bottom: 1px solid $border; padding: 12px 20px; display: flex; align-items: center; gap: 8px; }');
    buffer.writeln('.header .badge { background: ${isDark ? 'rgba(99,102,241,0.2)' : '#EEF2FF'}; color: ${isDark ? '#818CF8' : '#4338CA'}; padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: 600; }');
    buffer.writeln('.header .filename { font-size: 12px; font-weight: 600; color: $textSecondary; }');
    buffer.writeln('.header .readonly { font-size: 9px; color: ${isDark ? '#475569' : '#94A3B8'}; margin-left: auto; }');
    buffer.writeln('.content { padding: 16px 0; }');
    buffer.writeln('.line { display: flex; font-family: "Consolas", "Courier New", monospace; font-size: 12px; line-height: 1.8; }');
    buffer.writeln('.line:hover { background: ${isDark ? '#253347' : '#F8FAFC'}; }');
    buffer.writeln('.line-num { width: 48px; text-align: right; padding-right: 16px; color: $lineNumColor; user-select: none; flex-shrink: 0; }');
    buffer.writeln('.line-content { flex: 1; white-space: pre-wrap; word-break: break-all; padding-right: 16px; }');
    buffer.writeln('</style></head><body>');

    buffer.writeln('<div class="header">');
    buffer.writeln('<span class="badge">.claude</span>');
    buffer.writeln('<span class="filename">${_escapeHtml(fileName)}</span>');
    buffer.writeln('<span class="readonly">읽기 전용</span>');
    buffer.writeln('</div>');

    buffer.writeln('<div class="content">');
    for (var i = 0; i < lines.length; i++) {
      buffer.writeln('<div class="line"><span class="line-num">${i + 1}</span><span class="line-content">${lines[i]}</span></div>');
    }
    buffer.writeln('</div>');

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  /// 소스 .claude 폴더의 설치 항목 요약을 반환한다.
  /// 설치 전 미리보기 및 제외 대상 표시용.
  ({int totalFiles, List<String> folders, List<String> rootFiles, List<String> excludedFiles}) getClaudeInstallSummary() {
    final source = sourceClaudePath;
    if (source.isEmpty) {
      return (totalFiles: 0, folders: <String>[], rootFiles: <String>[], excludedFiles: <String>[]);
    }

    const excludeFiles = ['settings.local.json'];
    final sourceDir = Directory(source);
    final folders = <String>[];
    final rootFiles = <String>[];
    var totalFiles = 0;

    for (final entity in sourceDir.listSync()) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        // 디렉토리 내 파일 수
        final count = entity.listSync(recursive: true).whereType<File>().length;
        folders.add('$name/ ($count개)');
        totalFiles += count;
      } else if (entity is File) {
        if (!excludeFiles.contains(name)) {
          rootFiles.add(name);
          totalFiles++;
        }
      }
    }

    return (totalFiles: totalFiles, folders: folders, rootFiles: rootFiles, excludedFiles: excludeFiles);
  }

  // ─── Markdown → HTML Rendering ──────────────────────────────────────

  /// Markdown 파일 내용을 스타일링된 HTML로 변환한다.
  /// WebView에서 렌더링하기 위한 단일 HTML 문서를 반환한다.
  String generateMarkdownHtml(String markdown, String fileName, {bool isDark = false}) {
    final bg = isDark ? '#0F172A' : '#F8FAFC';
    final textPrimary = isDark ? '#F1F5F9' : '#1E293B';
    final textSecondary = isDark ? '#94A3B8' : '#64748B';
    final textTertiary = isDark ? '#64748B' : '#94A3B8';
    final border = isDark ? '#334155' : '#E2E8F0';
    final headerBg = isDark ? '#1E293B' : '#F1F5F9';
    final codeBg = isDark ? '#0F172A' : '#F1F5F9';
    final codeBorder = isDark ? '#334155' : '#E2E8F0';
    final inlineCodeBg = isDark ? '#334155' : '#E2E8F0';
    final linkColor = isDark ? '#818CF8' : '#4F46E5';
    final blockquoteBorder = isDark ? '#818CF8' : '#C7D2FE';
    final blockquoteBg = isDark ? 'rgba(99,102,241,0.08)' : '#EEF2FF';
    final tableBorder = isDark ? '#334155' : '#E2E8F0';
    final tableHeaderBg = isDark ? '#1E293B' : '#F1F5F9';
    final hrColor = isDark ? '#334155' : '#E2E8F0';

    final html = _convertMarkdownToHtml(markdown);

    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="ko"><head><meta charset="UTF-8">');
    buffer.writeln('<style>');
    buffer.writeln('* { font-family: "Pretendard", -apple-system, sans-serif; margin: 0; padding: 0; box-sizing: border-box; }');
    buffer.writeln('body { background: $bg; color: $textPrimary; }');
    buffer.writeln('.header { background: $headerBg; border-bottom: 1px solid $border; padding: 12px 20px; display: flex; align-items: center; gap: 8px; }');
    buffer.writeln('.header .badge { background: ${isDark ? 'rgba(52,211,153,0.2)' : '#ECFDF5'}; color: ${isDark ? '#34D399' : '#047857'}; padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: 600; }');
    buffer.writeln('.header .filename { font-size: 12px; font-weight: 600; color: $textSecondary; }');
    buffer.writeln('.content { max-width: 800px; margin: 0 auto; padding: 32px 24px; line-height: 1.7; font-size: 14px; }');
    buffer.writeln('h1 { font-size: 24px; font-weight: 800; margin: 32px 0 16px; padding-bottom: 8px; border-bottom: 2px solid $border; }');
    buffer.writeln('h2 { font-size: 20px; font-weight: 700; margin: 28px 0 12px; padding-bottom: 6px; border-bottom: 1px solid $border; }');
    buffer.writeln('h3 { font-size: 16px; font-weight: 700; margin: 24px 0 8px; }');
    buffer.writeln('h4 { font-size: 14px; font-weight: 700; margin: 20px 0 6px; }');
    buffer.writeln('h5, h6 { font-size: 13px; font-weight: 600; margin: 16px 0 4px; color: $textSecondary; }');
    buffer.writeln('.content > h1:first-child { margin-top: 0; }');
    buffer.writeln('p { margin: 8px 0; }');
    buffer.writeln('ul, ol { margin: 8px 0; padding-left: 24px; }');
    buffer.writeln('li { margin: 4px 0; }');
    buffer.writeln('li > ul, li > ol { margin: 2px 0; }');
    buffer.writeln('a { color: $linkColor; text-decoration: none; }');
    buffer.writeln('a:hover { text-decoration: underline; }');
    buffer.writeln('code { background: $inlineCodeBg; padding: 2px 6px; border-radius: 4px; font-family: "Consolas", "Courier New", monospace; font-size: 12px; }');
    buffer.writeln('pre { background: $codeBg; border: 1px solid $codeBorder; border-radius: 8px; padding: 16px; margin: 12px 0; overflow-x: auto; }');
    buffer.writeln('pre code { background: transparent; padding: 0; font-size: 12px; line-height: 1.6; }');
    buffer.writeln('blockquote { border-left: 3px solid $blockquoteBorder; background: $blockquoteBg; padding: 12px 16px; margin: 12px 0; border-radius: 0 8px 8px 0; }');
    buffer.writeln('blockquote p { margin: 4px 0; color: $textSecondary; }');
    buffer.writeln('table { width: 100%; border-collapse: collapse; margin: 12px 0; font-size: 13px; }');
    buffer.writeln('th { background: $tableHeaderBg; font-weight: 600; text-align: left; padding: 8px 12px; border: 1px solid $tableBorder; }');
    buffer.writeln('td { padding: 8px 12px; border: 1px solid $tableBorder; }');
    buffer.writeln('tr:hover td { background: ${isDark ? '#253347' : '#F8FAFC'}; }');
    buffer.writeln('hr { border: none; border-top: 1px solid $hrColor; margin: 24px 0; }');
    buffer.writeln('strong { font-weight: 700; }');
    buffer.writeln('em { font-style: italic; }');
    buffer.writeln('del { text-decoration: line-through; color: $textTertiary; }');
    buffer.writeln('img { max-width: 100%; border-radius: 8px; margin: 8px 0; }');
    buffer.writeln('.checkbox { margin-right: 6px; }');
    buffer.writeln('</style></head><body>');

    buffer.writeln('<div class="header">');
    buffer.writeln('<span class="badge">MD</span>');
    buffer.writeln('<span class="filename">${_escapeHtml(fileName)}</span>');
    buffer.writeln('</div>');

    buffer.writeln('<div class="content">');
    buffer.writeln(html);
    buffer.writeln('</div>');

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  /// 간이 Markdown → HTML 변환기
  /// 외부 패키지 없이 주요 Markdown 문법을 처리한다.
  String _convertMarkdownToHtml(String markdown) {
    final lines = markdown.split('\n');
    final buffer = StringBuffer();
    var inCodeBlock = false;
    final codeBuffer = StringBuffer();
    var inList = false;
    var listType = ''; // 'ul' or 'ol'
    var inTable = false;
    final tableRows = <String>[];

    void closeList() {
      if (inList) {
        buffer.writeln('</$listType>');
        inList = false;
        listType = '';
      }
    }

    void closeTable() {
      if (inTable && tableRows.isNotEmpty) {
        buffer.writeln('<table>');
        for (var i = 0; i < tableRows.length; i++) {
          // 구분선 행(---|---) 건너뛰기
          if (i == 1 && RegExp(r'^\|[\s\-:|]+\|$').hasMatch(tableRows[i].trim())) {
            continue;
          }
          final cells = tableRows[i]
              .trim()
              .replaceAll(RegExp(r'^\|'), '')
              .replaceAll(RegExp(r'\|$'), '')
              .split('|')
              .map((c) => c.trim())
              .toList();
          final tag = i == 0 ? 'th' : 'td';
          buffer.writeln('<tr>${cells.map((c) => '<$tag>${_processInline(c)}</$tag>').join()}</tr>');
        }
        buffer.writeln('</table>');
        tableRows.clear();
        inTable = false;
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 코드 블록 (```)
      if (line.trimLeft().startsWith('```')) {
        if (!inCodeBlock) {
          closeList();
          closeTable();
          inCodeBlock = true;
          codeBuffer.clear();
        } else {
          buffer.writeln('<pre><code>${_escapeHtml(codeBuffer.toString().trimRight())}</code></pre>');
          inCodeBlock = false;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.writeln(line);
        continue;
      }

      final trimmed = line.trim();

      // 빈 줄
      if (trimmed.isEmpty) {
        closeList();
        closeTable();
        continue;
      }

      // 테이블 (| 로 시작하고 끝나는 행)
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        closeList();
        if (!inTable) inTable = true;
        tableRows.add(trimmed);
        continue;
      } else {
        closeTable();
      }

      // 헤딩 (#)
      final headingMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(trimmed);
      if (headingMatch != null) {
        closeList();
        final level = headingMatch.group(1)!.length;
        final text = headingMatch.group(2)!;
        buffer.writeln('<h$level>${_processInline(text)}</h$level>');
        continue;
      }

      // 수평선 (---, ***, ___)
      if (RegExp(r'^[-*_]{3,}$').hasMatch(trimmed)) {
        closeList();
        buffer.writeln('<hr>');
        continue;
      }

      // 인용 (>)
      if (trimmed.startsWith('>')) {
        closeList();
        final quoteContent = trimmed.substring(1).trimLeft();
        buffer.writeln('<blockquote><p>${_processInline(quoteContent)}</p></blockquote>');
        continue;
      }

      // 비순서 목록 (- , * , + )
      final ulMatch = RegExp(r'^[\-*+]\s+(.+)$').firstMatch(trimmed);
      if (ulMatch != null) {
        closeTable();
        if (!inList || listType != 'ul') {
          closeList();
          buffer.writeln('<ul>');
          inList = true;
          listType = 'ul';
        }
        final content = ulMatch.group(1)!;
        // 체크박스 처리
        if (content.startsWith('[ ] ')) {
          buffer.writeln('<li><span class="checkbox">&#9744;</span>${_processInline(content.substring(4))}</li>');
        } else if (content.startsWith('[x] ') || content.startsWith('[X] ')) {
          buffer.writeln('<li><span class="checkbox">&#9745;</span>${_processInline(content.substring(4))}</li>');
        } else {
          buffer.writeln('<li>${_processInline(content)}</li>');
        }
        continue;
      }

      // 순서 목록 (1. , 2. , ...)
      final olMatch = RegExp(r'^\d+\.\s+(.+)$').firstMatch(trimmed);
      if (olMatch != null) {
        closeTable();
        if (!inList || listType != 'ol') {
          closeList();
          buffer.writeln('<ol>');
          inList = true;
          listType = 'ol';
        }
        buffer.writeln('<li>${_processInline(olMatch.group(1)!)}</li>');
        continue;
      }

      // 일반 단락
      closeList();
      buffer.writeln('<p>${_processInline(trimmed)}</p>');
    }

    // 남은 블록 닫기
    if (inCodeBlock) {
      buffer.writeln('<pre><code>${_escapeHtml(codeBuffer.toString().trimRight())}</code></pre>');
    }
    closeList();
    closeTable();

    return buffer.toString();
  }

  /// 인라인 Markdown 요소 처리 (bold, italic, code, link, image, strikethrough)
  String _processInline(String text) {
    var result = _escapeHtml(text);

    // 이미지: ![alt](url)
    result = result.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'),
      (m) => '<img src="${m.group(2)}" alt="${m.group(1)}">',
    );

    // 링크: [text](url)
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => '<a href="${m.group(2)}" target="_blank">${m.group(1)}</a>',
    );

    // 인라인 코드: `code`
    result = result.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) => '<code>${m.group(1)}</code>',
    );

    // 볼드+이탤릭: ***text*** or ___text___
    result = result.replaceAllMapped(
      RegExp(r'\*\*\*(.+?)\*\*\*|___(.+?)___'),
      (m) => '<strong><em>${m.group(1) ?? m.group(2)}</em></strong>',
    );

    // 볼드: **text** or __text__
    result = result.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*|__(.+?)__'),
      (m) => '<strong>${m.group(1) ?? m.group(2)}</strong>',
    );

    // 이탤릭: *text* or _text_
    result = result.replaceAllMapped(
      RegExp(r'\*(.+?)\*|_(.+?)_'),
      (m) => '<em>${m.group(1) ?? m.group(2)}</em>',
    );

    // 취소선: ~~text~~
    result = result.replaceAllMapped(
      RegExp(r'~~(.+?)~~'),
      (m) => '<del>${m.group(1)}</del>',
    );

    return result;
  }

  // ─── History HTML Generation ────────────────────────────────────────

  String generateHistoryHtml(List<TaskEntry> history, {bool isDark = false}) {
    if (history.isEmpty) {
      return _emptyHistoryHtml(isDark);
    }

    final bg = isDark ? '#0F172A' : '#F8FAFC';
    final cardBg = isDark ? '#1E293B' : '#FFFFFF';
    final cardHover = isDark ? '#253347' : '#F1F5F9';
    final textPrimary = isDark ? '#F1F5F9' : '#1E293B';
    final textSecondary = isDark ? '#94A3B8' : '#64748B';
    final textTertiary = isDark ? '#64748B' : '#94A3B8';
    final border = isDark ? '#334155' : '#E2E8F0';
    final timelineColor = isDark ? '#334155' : '#C7D2FE';
    final changePlus = isDark ? '#34D399' : '#047857';
    final decisionBg = isDark ? 'rgba(251,191,36,0.15)' : '#FFFBEB';
    final decisionColor = isDark ? '#FBBF24' : '#B45309';
    final barDone = '#34D399';
    final barPending = isDark ? '#334155' : '#E2E8F0';

    // 최신순 정렬 (마지막 로그 날짜 기준)
    final sorted = List<TaskEntry>.from(history)
      ..sort((a, b) {
        final dateA = a.logs.isNotEmpty ? a.logs.last.date : '';
        final dateB = b.logs.isNotEmpty ? b.logs.last.date : '';
        return dateB.compareTo(dateA);
      });

    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="ko"><head><meta charset="UTF-8">');
    buffer.writeln('<style>');
    buffer.writeln('* { font-family: "Pretendard", -apple-system, sans-serif; margin: 0; padding: 0; box-sizing: border-box; }');
    buffer.writeln('body { background: $bg; color: $textPrimary; padding: 24px; }');
    buffer.writeln('.header { font-size: 16px; font-weight: 800; margin-bottom: 4px; }');
    buffer.writeln('.subtitle { font-size: 12px; color: $textSecondary; margin-bottom: 24px; }');
    buffer.writeln('.timeline { position: relative; padding-left: 24px; }');
    buffer.writeln('.timeline::before { content: ""; position: absolute; left: 5px; top: 0; bottom: 0; width: 2px; background: $timelineColor; }');
    buffer.writeln('.item { position: relative; padding-bottom: 20px; }');
    buffer.writeln('.item:last-child { padding-bottom: 0; }');
    buffer.writeln('.dot { position: absolute; left: -24px; top: 0; width: 12px; height: 12px; border-radius: 50%; border: 2px solid $bg; }');
    buffer.writeln('.card { background: $cardBg; border: 1px solid $border; border-radius: 12px; padding: 14px; cursor: pointer; transition: background 0.15s; }');
    buffer.writeln('.card:hover { background: $cardHover; }');
    buffer.writeln('.card-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }');
    buffer.writeln('.card-title { display: flex; align-items: center; gap: 8px; }');
    buffer.writeln('.name { font-size: 13px; font-weight: 700; }');
    buffer.writeln('.badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: 600; }');
    buffer.writeln('.date { font-size: 10px; color: $textTertiary; }');
    buffer.writeln('.progress { display: flex; gap: 2px; margin-bottom: 10px; }');
    buffer.writeln('.progress-bar { height: 3px; flex: 1; border-radius: 2px; }');
    buffer.writeln('.summary-title { font-size: 12px; font-weight: 600; color: $textSecondary; margin-bottom: 8px; }');
    buffer.writeln('.changes { list-style: none; margin-bottom: 8px; }');
    buffer.writeln('.changes li { display: flex; align-items: flex-start; gap: 6px; margin-bottom: 4px; font-size: 11px; line-height: 1.5; }');
    buffer.writeln('.changes li .plus { color: $changePlus; font-weight: 700; font-size: 11px; flex-shrink: 0; margin-top: 1px; }');
    buffer.writeln('.decision { display: inline-flex; align-items: center; gap: 6px; padding: 3px 8px; border-radius: 6px; font-size: 10px; margin-bottom: 6px; background: $decisionBg; }');
    buffer.writeln('.decision-type { font-weight: 700; color: $decisionColor; }');
    buffer.writeln('.decision-note { color: $textTertiary; }');
    buffer.writeln('.stats { display: flex; gap: 12px; font-size: 10px; color: $textTertiary; }');
    buffer.writeln('.nav-hint { font-size: 9px; color: $textTertiary; margin-top: 8px; opacity: 0; transition: opacity 0.15s; }');
    buffer.writeln('.card:hover .nav-hint { opacity: 1; }');
    buffer.writeln('</style></head><body>');

    buffer.writeln('<div class="header">프로젝트 이력</div>');
    buffer.writeln('<div class="subtitle">총 ${history.length}개 태스크 · 최신순</div>');
    buffer.writeln('<div class="timeline">');

    for (final entry in sorted) {
      final lastStatus = entry.lastStatus;
      final dotColor = _statusDotColor(lastStatus);
      final taskId = entry.id ?? entry.slug;

      // 완료된 phase 집합
      final completedPhases = <String>{};
      for (final log in entry.logs) {
        if (log.status == '완료' || log.status == '승인' || log.status == '조건부승인') {
          completedPhases.add(log.phase);
        }
      }

      buffer.writeln('<div class="item">');
      buffer.writeln('<div class="dot" style="background:$dotColor"></div>');

      buffer.writeln('<div class="card" onclick="window.chrome.webview.postMessage(\'navigate:${_escapeHtml(taskId)}\')">');

      // Header: 이름 + 배지 + 날짜
      final lastDate = entry.logs.isNotEmpty ? entry.logs.last.date : '';
      final statusBg = _statusBadgeBg(lastStatus, isDark);
      final statusColor = _statusBadgeColor(lastStatus, isDark);
      buffer.writeln('<div class="card-header">');
      buffer.writeln('<div class="card-title">');
      buffer.writeln('<span class="name">${_escapeHtml(entry.name.isNotEmpty ? entry.name : entry.slug)}</span>');
      buffer.writeln('<span class="badge" style="background:$statusBg;color:$statusColor">$lastStatus</span>');
      buffer.writeln('</div>');
      buffer.writeln('<span class="date">$lastDate</span>');
      buffer.writeln('</div>');

      // Compact progress bar (4칸)
      buffer.writeln('<div class="progress">');
      for (final phase in ['기획', '디자인', '승인', '개발']) {
        final color = completedPhases.contains(phase) ? barDone : barPending;
        buffer.writeln('<div class="progress-bar" style="background:$color"></div>');
      }
      buffer.writeln('</div>');

      // Summary title
      buffer.writeln('<div class="summary-title">${_escapeHtml(entry.summaryTitle)}</div>');

      // Changes bullet list (PR style)
      final changes = entry.fallbackChanges;
      if (changes.isNotEmpty) {
        buffer.writeln('<ul class="changes">');
        for (final change in changes.take(5)) {
          buffer.writeln('<li><span class="plus">+</span><span>${_escapeHtml(change)}</span></li>');
        }
        buffer.writeln('</ul>');
      }

      // Decision badges
      if (entry.summary?.decisions != null) {
        for (final decision in entry.summary!.decisions) {
          buffer.writeln('<div class="decision">');
          buffer.writeln('<span class="decision-type">${_escapeHtml(decision.type)}</span>');
          if (decision.note.isNotEmpty) {
            buffer.writeln('<span class="decision-note">${_escapeHtml(decision.note)}</span>');
          }
          buffer.writeln('</div>');
        }
      }

      // Stats
      final filesChanged = entry.summary?.filesChanged ?? 0;
      final issues = entry.summary?.issues ?? 0;
      if (filesChanged > 0 || issues > 0) {
        buffer.writeln('<div class="stats">');
        if (filesChanged > 0) buffer.writeln('<span>📁 $filesChanged files</span>');
        buffer.writeln('<span>⚠️ $issues issues</span>');
        buffer.writeln('</div>');
      }

      buffer.writeln('<div class="nav-hint">클릭하여 태스크로 이동 →</div>');

      buffer.writeln('</div>'); // card
      buffer.writeln('</div>'); // item
    }

    buffer.writeln('</div>'); // timeline
    buffer.writeln('</body></html>');

    return buffer.toString();
  }

  String _emptyHistoryHtml(bool isDark) {
    final bg = isDark ? '#0F172A' : '#F8FAFC';
    final color = isDark ? '#64748B' : '#94A3B8';
    return '<!DOCTYPE html><html><head><meta charset="UTF-8"><style>'
        'body{background:$bg;display:flex;align-items:center;justify-content:center;height:100vh;font-family:Pretendard,sans-serif;}'
        'p{color:$color;font-size:14px;}'
        '</style></head><body><p>이력이 없습니다</p></body></html>';
  }

  String _escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _statusDotColor(String status) {
    switch (status) {
      case '완료': case '승인': case '조건부승인': return '#34D399';
      case '진행중': return '#A78BFA';
      case '기획': return '#60A5FA';
      case '반려': return '#FB7185';
      case '대기': return '#FBBF24';
      default: return '#94A3B8';
    }
  }

  String _statusBadgeBg(String status, bool isDark) {
    if (isDark) {
      switch (status) {
        case '완료': case '승인': case '조건부승인': return 'rgba(52,211,153,0.15)';
        case '진행중': return 'rgba(167,139,250,0.15)';
        case '기획': return 'rgba(96,165,250,0.15)';
        case '반려': return 'rgba(251,113,133,0.15)';
        case '대기': return 'rgba(251,191,36,0.15)';
        default: return 'rgba(148,163,184,0.15)';
      }
    }
    switch (status) {
      case '완료': case '승인': case '조건부승인': return '#ECFDF5';
      case '진행중': return '#F5F3FF';
      case '기획': return '#EFF6FF';
      case '반려': return '#FEF2F2';
      case '대기': return '#FFFBEB';
      default: return '#F1F5F9';
    }
  }

  String _statusBadgeColor(String status, bool isDark) {
    if (isDark) {
      switch (status) {
        case '완료': case '승인': case '조건부승인': return '#34D399';
        case '진행중': return '#A78BFA';
        case '기획': return '#60A5FA';
        case '반려': return '#FB7185';
        case '대기': return '#FBBF24';
        default: return '#94A3B8';
      }
    }
    switch (status) {
      case '완료': case '승인': case '조건부승인': return '#047857';
      case '진행중': return '#6D28D9';
      case '기획': return '#1D4ED8';
      case '반려': return '#DC2626';
      case '대기': return '#B45309';
      default: return '#334155';
    }
  }

}
