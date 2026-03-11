import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_entry.dart';
import '../providers/project_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/project_card.dart';
import '../widgets/add_project_dialog.dart';
import '../models/project.dart';

class DashboardScreen extends ConsumerWidget {
  final ValueChanged<String> onProjectTap;

  const DashboardScreen({super.key, required this.onProjectTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsProvider);

    return projectsAsync.when(
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (projects) => _DashboardContent(
        projects: projects,
        onProjectTap: onProjectTap,
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final List<Project> projects;
  final ValueChanged<String> onProjectTap;

  const _DashboardContent({
    required this.projects,
    required this.onProjectTap,
  });

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const AddProjectDialog(),
    );
    if (result == true) {
      ref.invalidate(projectsProvider);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Project project) async {
    final sc = semanticColors(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ContentDialog(
        title: Text('프로젝트를 삭제할까요?', style: TextStyle(fontWeight: FontWeight.w700, color: sc.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(text: project.name, style: TextStyle(fontWeight: FontWeight.w700, color: sc.textPrimary)),
                TextSpan(text: ' 프로젝트를 목록에서 제거합니다.', style: TextStyle(color: sc.textSecondary)),
              ]),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text('실제 파일은 삭제되지 않습니다.', style: TextStyle(fontSize: 13, color: sc.textSecondary)),
          ],
        ),
        actions: [
          Button(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(
            style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(AppColors.red500)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제', style: TextStyle(color: Color(0xFFFFFFFF))),
          ),
        ],
      ),
    );

    if (result == true) {
      await ref.read(projectsProvider.notifier).deleteProject(project.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내 프로젝트',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: sc.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    projects.isEmpty ? '프로젝트를 등록하세요' : '${projects.length}개 프로젝트 관리 중',
                    style: TextStyle(fontSize: 13, color: sc.textTertiary),
                  ),
                ],
              ),
              FilledButton(
                onPressed: () => _showAddDialog(context, ref),
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(isDark ? AppColors.primary500 : AppColors.primary600),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.add, size: 14, color: Color(0xFFFFFFFF)),
                    SizedBox(width: 8),
                    Text('새 프로젝트', style: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Grid
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                int crossAxisCount;
                if (width > 900) {
                  crossAxisCount = 3;
                } else if (width > 600) {
                  crossAxisCount = 2;
                } else {
                  crossAxisCount = 1;
                }

                final items = <Widget>[
                  ...projects.map((project) {
                    final scanAsync = ref.watch(projectScanProvider(project.id));
                    List<TaskEntry>? history;
                    scanAsync.whenData((data) => history = data.history);

                    return ProjectCard(
                      project: project,
                      history: history,
                      onTap: () => onProjectTap(project.id),
                      onDelete: () => _confirmDelete(context, ref, project),
                    );
                  }),

                  // Add card
                  GestureDetector(
                    onTap: () => _showAddDialog(context, ref),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sc.border,
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.add, size: 28, color: sc.textTertiary),
                              const SizedBox(height: 8),
                              Text(
                                '새 프로젝트 추가',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: sc.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ];

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.6,
                  children: items,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
