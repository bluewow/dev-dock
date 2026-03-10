import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/task_entry.dart';
import '../models/scanned_file.dart';
import '../services/project_service.dart';

// ─── Service Provider ─────────────────────────────────────────────────────────

final projectServiceProvider = Provider<ProjectService>((ref) {
  return ProjectService();
});

// ─── Projects List ────────────────────────────────────────────────────────────

final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(ProjectsNotifier.new);

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() async {
    return ref.read(projectServiceProvider).getProjects();
  }

  Future<Project> addProject({
    required String name,
    required String path,
    String color = 'emerald',
  }) async {
    final service = ref.read(projectServiceProvider);
    final project = await service.addProject(name: name, path: path, color: color);
    ref.invalidateSelf();
    return project;
  }

  Future<void> deleteProject(String id) async {
    final service = ref.read(projectServiceProvider);
    await service.deleteProject(id);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

// ─── Selected Project ─────────────────────────────────────────────────────────

final selectedProjectIdProvider = StateProvider<String?>((ref) => null);

final selectedProjectProvider = FutureProvider<Project?>((ref) async {
  final id = ref.watch(selectedProjectIdProvider);
  if (id == null) return null;
  final service = ref.read(projectServiceProvider);
  return service.findProject(id);
});

// ─── Project Scan ─────────────────────────────────────────────────────────────

final projectScanProvider = FutureProvider.family<
    ({List<ScannedTask> tasks, List<TaskEntry>? history}), String>(
  (ref, projectId) async {
    final service = ref.read(projectServiceProvider);
    final project = await service.findProject(projectId);
    if (project == null) {
      return (tasks: <ScannedTask>[], history: null);
    }
    return service.scanProject(project.path);
  },
);

// ─── Sidebar State ────────────────────────────────────────────────────────────

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

// ─── Viewer State ─────────────────────────────────────────────────────────────

final selectedFileProvider = StateProvider<ScannedFile?>((ref) => null);
final selectedTaskSlugProvider = StateProvider<String?>((ref) => null);
