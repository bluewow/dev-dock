import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:io';
import '../models/project.dart';
import '../models/task_entry.dart';
import '../models/scanned_file.dart';
import '../providers/project_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final String projectId;
  final VoidCallback onBack;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.onBack,
  });

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  String _activeTab = 'tasks';
  String? _selectedTaskSlug;
  ScannedFile? _selectedFile;
  final _webviewController = WebviewController();
  bool _webviewReady = false;
  final _commentController = TextEditingController();
  bool _submittingDecision = false;

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      await _webviewController.initialize();
      setState(() => _webviewReady = true);
    } catch (e) {
      debugPrint('WebView init error: $e');
    }
  }

  @override
  void dispose() {
    _webviewController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _openFile(ScannedFile file, String taskSlug) async {
    setState(() {
      _selectedFile = file;
      _selectedTaskSlug = taskSlug;
    });

    if (_webviewReady && file.absolutePath.isNotEmpty) {
      final uri = Uri.file(file.absolutePath);
      await _webviewController.loadUrl(uri.toString());
    }
  }

  Future<void> _submitDecision(String decision, Project project, List<TaskEntry>? history) async {
    if (_selectedTaskSlug == null || history == null) return;

    // Find the matching history entry slug
    String taskSlug = _selectedTaskSlug!;
    for (final entry in history) {
      final entryId = entry.id ?? entry.slug;
      if (_selectedTaskSlug!.contains(entryId) || _selectedTaskSlug!.contains(entry.slug)) {
        taskSlug = entry.slug;
        break;
      }
    }

    setState(() => _submittingDecision = true);

    try {
      final service = ref.read(projectServiceProvider);
      await service.addDecision(
        projectPath: project.path,
        taskSlug: taskSlug,
        decision: decision,
        note: _commentController.text.trim(),
      );
      _commentController.clear();
      ref.invalidate(projectScanProvider(widget.projectId));
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context, builder: (_, close) {
          return InfoBar(
            title: Text('오류: ${e.toString().replaceAll("Exception: ", "")}'),
            severity: InfoBarSeverity.error,
            action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
          );
        });
      }
    }

    setState(() => _submittingDecision = false);
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final scanAsync = ref.watch(projectScanProvider(widget.projectId));

    // Set selected project
    ref.read(selectedProjectIdProvider.notifier).state = widget.projectId;

    return projectAsync.when(
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (project) {
        if (project == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('프로젝트를 찾을 수 없습니다.', style: TextStyle(color: AppColors.slate400)),
                const SizedBox(height: 16),
                HyperlinkButton(onPressed: widget.onBack, child: const Text('대시보드로 돌아가기')),
              ],
            ),
          );
        }

        return scanAsync.when(
          loading: () => const Center(child: ProgressRing()),
          error: (e, _) => Center(child: Text('스캔 오류: $e')),
          data: (scan) => _buildContent(project, scan.tasks, scan.history),
        );
      },
    );
  }

  Widget _buildContent(Project project, List<ScannedTask> tasks, List<TaskEntry>? history) {
    return Row(
      children: [
        // Left Panel: Task list
        Container(
          width: 280,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: AppColors.slate200)),
          ),
          child: Column(
            children: [
              // Project header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: const Row(
                        children: [
                          Icon(FluentIcons.chevron_left, size: 12, color: AppColors.slate400),
                          SizedBox(width: 4),
                          Text('프로젝트 목록', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.dotColor(project.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            project.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.path,
                      style: const TextStyle(fontSize: 10, color: AppColors.slate400, fontFamily: 'Consolas'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Tab bar
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.slate100)),
                ),
                child: Row(
                  children: [
                    _TabButton(label: '태스크', isActive: _activeTab == 'tasks', onTap: () => setState(() => _activeTab = 'tasks')),
                    _TabButton(label: '산출물', isActive: _activeTab == 'artifacts', onTap: () => setState(() => _activeTab = 'artifacts')),
                    _TabButton(label: '이력', isActive: _activeTab == 'history', onTap: () => setState(() => _activeTab = 'history')),
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _activeTab == 'tasks'
                      ? _buildTasksList(tasks, history)
                      : _activeTab == 'artifacts'
                          ? _buildArtifactsList(tasks)
                          : _buildHistoryList(history),
                ),
              ),
            ],
          ),
        ),

        // Right Panel: Viewer
        Expanded(child: _buildViewer(project, history)),
      ],
    );
  }

  Widget _buildTasksList(List<ScannedTask> tasks, List<TaskEntry>? history) {
    if (tasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('산출물이 없습니다', style: TextStyle(fontSize: 12, color: AppColors.slate400))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '태스크 목록 (${tasks.length})',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate400),
          ),
        ),
        const SizedBox(height: 4),
        ...tasks.map((task) {
          final isSelected = _selectedTaskSlug == task.slug;
          final lastStatus = _getTaskStatus(task.slug, history);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTaskSlug = task.slug);
                final htmlFile = task.files.where((f) => f.type == 'html').firstOrNull;
                if (htmlFile != null) _openFile(htmlFile, task.slug);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary50.withValues(alpha: 0.5) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary200 : AppColors.slate200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatusBadge(status: lastStatus),
                        if (task.hasSpec)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.emerald50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('spec', style: TextStyle(fontSize: 9, color: AppColors.emerald700, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(task.slug, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: task.files.map((f) {
                        final isFileSelected = _selectedFile?.relativePath == f.relativePath;
                        return GestureDetector(
                          onTap: () => _openFile(f, task.slug),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isFileSelected
                                  ? AppColors.primary600
                                  : f.type == 'html'
                                      ? AppColors.primary50
                                      : f.type == 'md'
                                          ? AppColors.emerald50
                                          : AppColors.slate100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              f.name,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: isFileSelected
                                    ? Colors.white
                                    : f.type == 'html'
                                        ? AppColors.primary700
                                        : f.type == 'md'
                                            ? AppColors.emerald700
                                            : AppColors.slate500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildArtifactsList(List<ScannedTask> tasks) {
    final allFiles = tasks.expand((t) => t.files.map((f) => (task: t, file: f))).toList();

    if (allFiles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('산출물이 없습니다', style: TextStyle(fontSize: 12, color: AppColors.slate400))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text('전체 산출물', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate400)),
        ),
        const SizedBox(height: 4),
        ...allFiles.map((item) {
          final isSelected = _selectedFile?.relativePath == item.file.relativePath;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => _openFile(item.file, item.task.slug),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary50.withValues(alpha: 0.5) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? AppColors.primary200 : AppColors.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(FluentIcons.document, size: 12, color: AppColors.slate400),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(item.file.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.task.slug}  |  ${(item.file.size / 1024).toStringAsFixed(1)}KB',
                      style: const TextStyle(fontSize: 9, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHistoryList(List<TaskEntry>? history) {
    if (history == null || history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: Text('이력이 없습니다', style: TextStyle(fontSize: 12, color: AppColors.slate400))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text('이력', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate400)),
        ),
        const SizedBox(height: 4),
        ...history.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name.isNotEmpty ? entry.name : entry.slug,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  ...entry.logs.map((log) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: AppColors.slate300,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(log.date, style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
                                    const SizedBox(width: 6),
                                    Text(log.phase, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    StatusBadge(status: log.status),
                                  ],
                                ),
                                if (log.note.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(log.note, style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildViewer(Project project, List<TaskEntry>? history) {
    if (_selectedFile == null) {
      return Container(
        color: AppColors.slate50,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.document, size: 48, color: AppColors.slate200),
              SizedBox(height: 16),
              Text('산출물을 선택하세요', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.slate400)),
              SizedBox(height: 4),
              Text('왼쪽 목록에서 파일을 클릭하면 이 영역에 표시됩니다', style: TextStyle(fontSize: 11, color: AppColors.slate400)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Viewer header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.slate200)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedFile!.name,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary700),
                ),
              ),
              const SizedBox(width: 12),
              Text(_selectedTaskSlug ?? '', style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
              const Spacer(),
              IconButton(
                icon: const Icon(FluentIcons.open_in_new_window, size: 14, color: AppColors.slate400),
                onPressed: () {
                  if (_selectedFile != null && File(_selectedFile!.absolutePath).existsSync()) {
                    Process.run('cmd', ['/c', 'start', '', _selectedFile!.absolutePath]);
                  }
                },
              ),
              IconButton(
                icon: const Icon(FluentIcons.clear, size: 14, color: AppColors.slate400),
                onPressed: () => setState(() {
                  _selectedFile = null;
                  _selectedTaskSlug = null;
                }),
              ),
            ],
          ),
        ),

        // WebView
        Expanded(
          child: _webviewReady
              ? Webview(_webviewController)
              : const Center(child: ProgressRing()),
        ),

        // Decision bar
        if (_selectedTaskSlug != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.slate200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextBox(
                    controller: _commentController,
                    placeholder: '코멘트를 입력하세요...',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Button(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(AppColors.red50),
                    foregroundColor: WidgetStatePropertyAll(AppColors.red600),
                    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  onPressed: _submittingDecision ? null : () => _submitDecision('반려', project, history),
                  child: const Text('반려', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: ButtonStyle(
                    backgroundColor: const WidgetStatePropertyAll(AppColors.primary600),
                    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  onPressed: _submittingDecision ? null : () => _submitDecision('승인', project, history),
                  child: const Text('승인', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _getTaskStatus(String slug, List<TaskEntry>? history) {
    if (history == null) return '미확인';
    for (final entry in history) {
      final id = entry.id ?? entry.slug;
      if (slug.contains(id) || slug.contains(entry.slug)) {
        return entry.lastStatus;
      }
    }
    return '미확인';
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primary600 : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? AppColors.primary600 : AppColors.slate400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
