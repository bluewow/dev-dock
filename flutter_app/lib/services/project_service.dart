import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import '../models/task_entry.dart';
import '../models/scanned_file.dart';

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

      for (final folder in taskFolders) {
        final files = <ScannedFile>[];
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
          files.add(ScannedFile(
            name: name,
            relativePath: relativePath,
            absolutePath: entry.path,
            type: type,
            size: stat.size,
            modifiedAt: stat.modified,
          ));
        }

        tasks.add(ScannedTask(
          slug: p.basename(folder.path),
          files: files,
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
    buffer.writeln('.item { position: relative; padding-bottom: 24px; }');
    buffer.writeln('.item:last-child { padding-bottom: 0; }');
    buffer.writeln('.dot { position: absolute; left: -24px; top: 0; width: 12px; height: 12px; border-radius: 50%; border: 2px solid $bg; }');
    buffer.writeln('.date { font-size: 11px; color: $textTertiary; margin-bottom: 6px; }');
    buffer.writeln('.card { background: $cardBg; border: 1px solid $border; border-radius: 12px; padding: 12px; cursor: pointer; transition: background 0.15s; }');
    buffer.writeln('.card:hover { background: $cardHover; }');
    buffer.writeln('.task-name { font-size: 13px; font-weight: 700; margin-bottom: 8px; display: flex; align-items: center; gap: 8px; }');
    buffer.writeln('.badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: 600; }');
    buffer.writeln('.phases { display: flex; flex-wrap: wrap; gap: 4px; margin-bottom: 8px; }');
    buffer.writeln('.phase { padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: 500; }');
    buffer.writeln('.note { font-size: 10px; color: $textTertiary; margin-top: 6px; }');
    buffer.writeln('.nav-hint { font-size: 9px; color: $textTertiary; margin-top: 8px; opacity: 0; transition: opacity 0.15s; }');
    buffer.writeln('.card:hover .nav-hint { opacity: 1; }');
    buffer.writeln('</style></head><body>');

    buffer.writeln('<div class="header">프로젝트 이력</div>');
    buffer.writeln('<div class="subtitle">총 ${history.length}개 태스크 · 최신순</div>');
    buffer.writeln('<div class="timeline">');

    for (final entry in sorted) {
      final lastStatus = entry.lastStatus;
      final dotColor = _statusDotColor(lastStatus);
      // id가 있으면 id 사용, 없으면 slug 사용 (태스크 폴더명 매칭용)
      final taskId = entry.id ?? entry.slug;

      buffer.writeln('<div class="item">');
      buffer.writeln('<div class="dot" style="background:$dotColor"></div>');

      // 날짜
      final lastDate = entry.logs.isNotEmpty ? entry.logs.last.date : '';
      buffer.writeln('<div class="date">$lastDate</div>');

      buffer.writeln('<div class="card" onclick="window.chrome.webview.postMessage(\'navigate:${_escapeHtml(taskId)}\')">');

      // 이름 + 상태 배지
      final statusBg = _statusBadgeBg(lastStatus, isDark);
      final statusColor = _statusBadgeColor(lastStatus, isDark);
      buffer.writeln('<div class="task-name">');
      buffer.writeln('<span>${_escapeHtml(entry.name.isNotEmpty ? entry.name : entry.slug)}</span>');
      buffer.writeln('<span class="badge" style="background:$statusBg;color:$statusColor">$lastStatus</span>');
      buffer.writeln('</div>');

      // Phase 칩
      buffer.writeln('<div class="phases">');
      for (final log in entry.logs) {
        final phaseBg = _phaseBg(log.phase, isDark);
        final phaseColor = _phaseColor(log.phase, isDark);
        buffer.writeln('<span class="phase" style="background:$phaseBg;color:$phaseColor">${log.phase} ${log.status}</span>');
      }
      buffer.writeln('</div>');

      // 마지막 note
      final lastNote = entry.logs.isNotEmpty ? entry.logs.last.note : '';
      if (lastNote.isNotEmpty) {
        buffer.writeln('<div class="note">${_escapeHtml(lastNote)}</div>');
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
      case '완료': case '승인': return '#34D399';
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
        case '완료': case '승인': return 'rgba(52,211,153,0.15)';
        case '진행중': return 'rgba(167,139,250,0.15)';
        case '기획': return 'rgba(96,165,250,0.15)';
        case '반려': return 'rgba(251,113,133,0.15)';
        case '대기': return 'rgba(251,191,36,0.15)';
        default: return 'rgba(148,163,184,0.15)';
      }
    }
    switch (status) {
      case '완료': case '승인': return '#ECFDF5';
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
        case '완료': case '승인': return '#34D399';
        case '진행중': return '#A78BFA';
        case '기획': return '#60A5FA';
        case '반려': return '#FB7185';
        case '대기': return '#FBBF24';
        default: return '#94A3B8';
      }
    }
    switch (status) {
      case '완료': case '승인': return '#047857';
      case '진행중': return '#6D28D9';
      case '기획': return '#1D4ED8';
      case '반려': return '#DC2626';
      case '대기': return '#B45309';
      default: return '#334155';
    }
  }

  String _phaseBg(String phase, bool isDark) {
    if (isDark) {
      switch (phase) {
        case '기획': return 'rgba(96,165,250,0.15)';
        case '디자인': return 'rgba(167,139,250,0.15)';
        case '승인': return 'rgba(251,191,36,0.15)';
        case '개발': return 'rgba(52,211,153,0.15)';
        default: return 'rgba(148,163,184,0.15)';
      }
    }
    switch (phase) {
      case '기획': return '#EFF6FF';
      case '디자인': return '#F5F3FF';
      case '승인': return '#FFFBEB';
      case '개발': return '#ECFDF5';
      default: return '#F1F5F9';
    }
  }

  String _phaseColor(String phase, bool isDark) {
    if (isDark) {
      switch (phase) {
        case '기획': return '#60A5FA';
        case '디자인': return '#A78BFA';
        case '승인': return '#FBBF24';
        case '개발': return '#34D399';
        default: return '#94A3B8';
      }
    }
    switch (phase) {
      case '기획': return '#1D4ED8';
      case '디자인': return '#6D28D9';
      case '승인': return '#B45309';
      case '개발': return '#047857';
      default: return '#334155';
    }
  }
}
