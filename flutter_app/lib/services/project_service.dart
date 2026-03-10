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
}
