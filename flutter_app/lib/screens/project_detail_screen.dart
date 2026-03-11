import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
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
  String? _selectedTaskSlug;
  ScannedFile? _selectedFile;
  final _webviewController = WebviewController();
  bool _webviewReady = false;
  final _commentController = TextEditingController();
  bool _submittingDecision = false;
  bool _showingHistory = false;
  StreamSubscription<FileSystemEvent>? _fileWatcher;
  StreamSubscription<dynamic>? _webMessageSubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _updateSelectedProject();
    _initWebview();
    _startFileWatcher();
  }

  Future<void> _initWebview() async {
    try {
      await _webviewController.initialize();
      _webMessageSubscription = _webviewController.webMessage.listen(_onWebMessage);
      setState(() => _webviewReady = true);
    } catch (e) {
      debugPrint('WebView init error: $e');
    }
  }

  /// 이력 HTML에서 카드 클릭 시 해당 태스크로 이동
  void _onWebMessage(dynamic message) {
    final msg = message?.toString() ?? '';
    if (!msg.startsWith('navigate:')) return;
    final taskId = msg.substring('navigate:'.length);
    if (taskId.isEmpty || !mounted) return;

    // 스캔된 태스크 목록에서 매칭되는 slug 찾기
    final scanAsync = ref.read(projectScanProvider(widget.projectId));
    final tasks = scanAsync.valueOrNull?.tasks ?? [];

    for (final task in tasks) {
      if (task.slug.contains(taskId) || taskId.contains(task.slug)) {
        setState(() {
          _selectedTaskSlug = task.slug;
          _showingHistory = false;
        });
        // 첫 HTML 파일 자동 열기
        final htmlFile = task.files.where((f) => f.type == 'html').firstOrNull;
        if (htmlFile != null) {
          _openFile(htmlFile, task.slug);
        }
        return;
      }
    }
  }

  /// docs/tasks/ 디렉토리를 감시하여 변경 시 스캔을 재실행한다
  Future<void> _startFileWatcher() async {
    final service = ref.read(projectServiceProvider);
    final project = await service.findProject(widget.projectId);
    if (project == null) return;

    final tasksDir = Directory(p.join(project.path, 'docs', 'tasks'));
    if (!tasksDir.existsSync()) return;

    _fileWatcher = tasksDir
        .watch(events: FileSystemEvent.all, recursive: true)
        .listen((event) {
      // 디바운스: 짧은 시간 내 다수 이벤트를 하나로 묶는다
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.read(scanTriggerProvider.notifier).state++;
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _fileWatcher?.cancel();
    _webMessageSubscription?.cancel();
    _webviewController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _openFile(ScannedFile file, String taskSlug) async {
    setState(() {
      _selectedFile = file;
      _selectedTaskSlug = taskSlug;
      _showingHistory = false;
    });

    if (_webviewReady && file.absolutePath.isNotEmpty) {
      final uri = Uri.file(file.absolutePath);
      await _webviewController.loadUrl(uri.toString());
    }
  }

  Future<void> _showHistory(Project project, List<TaskEntry>? history) async {
    if (!_webviewReady) return;

    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final service = ref.read(projectServiceProvider);
    final html = service.generateHistoryHtml(history ?? [], isDark: isDark);

    // 임시 파일 생성하여 WebView에 로드
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/devdock_history_${project.id.hashCode}.html');
    await tempFile.writeAsString(html);

    setState(() {
      _showingHistory = true;
      _selectedFile = null;
      _selectedTaskSlug = null;
    });

    final uri = Uri.file(tempFile.path);
    await _webviewController.loadUrl(uri.toString());
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
  void didUpdateWidget(covariant ProjectDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _updateSelectedProject();
    }
  }

  void _updateSelectedProject() {
    Future(() {
      if (mounted) {
        ref.read(selectedProjectIdProvider.notifier).state = widget.projectId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final scanAsync = ref.watch(projectScanProvider(widget.projectId));

    final sc = semanticColors(context);

    return projectAsync.when(
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (project) {
        if (project == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('프로젝트를 찾을 수 없습니다.', style: TextStyle(color: sc.textTertiary)),
                const SizedBox(height: 16),
                HyperlinkButton(onPressed: widget.onBack, child: const Text('대시보드로 돌아가기')),
              ],
            ),
          );
        }

        return scanAsync.when(
          loading: () => const Center(child: ProgressRing()),
          error: (e, _) => Center(child: Text('스캔 오류: $e')),
          data: (scan) => Container(
            color: sc.scaffoldBg,
            child: _buildContent(project, scan.tasks, scan.history),
          ),
        );
      },
    );
  }

  Widget _buildContent(Project project, List<ScannedTask> tasks, List<TaskEntry>? history) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final filter = ref.watch(taskFilterProvider);

    // 필터 적용
    final filteredTasks = tasks.where((task) {
      if (filter == '전체') return true;
      final status = _getTaskStatus(task.slug, history);
      if (filter == '완료') return status == '완료' || status == '승인';
      if (filter == '진행중') return status != '완료' && status != '승인';
      return true;
    }).toList();

    return Row(
      children: [
        // Left Panel: Task list
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: sc.cardBg,
            border: Border(right: BorderSide(color: sc.border)),
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
                      child: Row(
                        children: [
                          Icon(FluentIcons.chevron_left, size: 12, color: sc.textTertiary),
                          const SizedBox(width: 4),
                          Text('프로젝트 목록', style: TextStyle(fontSize: 11, color: sc.textTertiary)),
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
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: sc.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.path,
                      style: TextStyle(fontSize: 10, color: sc.textTertiary, fontFamily: 'Consolas'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Task header with filter + history button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: sc.borderSubtle)),
                ),
                child: Column(
                  children: [
                    // 태스크 수 + 이력 버튼
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '태스크 (${filteredTasks.length})',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc.textTertiary),
                        ),
                        GestureDetector(
                          onTap: () => _showHistory(project, history),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.primary500.withValues(alpha: 0.15) : AppColors.primary50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.history, size: 10, color: isDark ? AppColors.primary400 : AppColors.primary600),
                                const SizedBox(width: 4),
                                Text(
                                  '이력',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.primary400 : AppColors.primary600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 상태 필터
                    Row(
                      children: ['전체', '완료', '진행중'].map((label) {
                        final isActive = filter == label;
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: GestureDetector(
                            onTap: () => ref.read(taskFilterProvider.notifier).state = label,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? (isDark ? AppColors.primary500.withValues(alpha: 0.2) : AppColors.primary600)
                                    : (isDark ? sc.hoverBg : sc.borderSubtle),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  color: isActive
                                      ? (isDark ? AppColors.primary400 : const Color(0xFFFFFFFF))
                                      : sc.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // Task list content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _buildTasksList(filteredTasks, history),
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
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(child: Text('해당 태스크가 없습니다', style: TextStyle(fontSize: 12, color: sc.textTertiary))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...tasks.map((task) {
          final isSelected = _selectedTaskSlug == task.slug;
          final lastStatus = _getTaskStatus(task.slug, history);
          final taskName = _getTaskName(task.slug, history);
          final phases = _getTaskPhases(task.slug, history);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTaskSlug = task.slug;
                  _showingHistory = false;
                });
                final htmlFile = task.files.where((f) => f.type == 'html').firstOrNull;
                if (htmlFile != null) _openFile(htmlFile, task.slug);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.primary500.withValues(alpha: 0.1) : AppColors.primary50.withValues(alpha: 0.5))
                      : sc.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? (isDark ? AppColors.primary500 : AppColors.primary200)
                        : sc.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status + Spec + Progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            StatusBadge(status: lastStatus),
                            if (task.hasSpec) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.emerald400.withValues(alpha: 0.15) : AppColors.emerald50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('spec', style: TextStyle(
                                  fontSize: 9,
                                  color: isDark ? AppColors.emerald400 : AppColors.emerald700,
                                  fontWeight: FontWeight.w600,
                                )),
                              ),
                            ],
                          ],
                        ),
                        // Progress indicator (4 pills)
                        Row(
                          children: _buildProgressPills(phases, isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Task slug
                    Text(task.slug, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: sc.textPrimary)),
                    // Task name (description)
                    if (taskName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(taskName, style: TextStyle(fontSize: 10, color: sc.textTertiary)),
                    ],
                    const SizedBox(height: 8),
                    // File chips with icons
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: task.files.map((f) {
                        final isFileSelected = _selectedFile?.relativePath == f.relativePath;
                        return GestureDetector(
                          onTap: () => _openFile(f, task.slug),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isFileSelected
                                  ? (isDark ? AppColors.primary500 : AppColors.primary600)
                                  : f.type == 'html'
                                      ? (isDark ? AppColors.primary500.withValues(alpha: 0.15) : AppColors.primary50)
                                      : f.type == 'md'
                                          ? (isDark ? AppColors.emerald400.withValues(alpha: 0.15) : AppColors.emerald50)
                                          : sc.hoverBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FluentIcons.document,
                                  size: 9,
                                  color: isFileSelected
                                      ? const Color(0xFFFFFFFF)
                                      : f.type == 'html'
                                          ? (isDark ? AppColors.primary400 : AppColors.primary700)
                                          : f.type == 'md'
                                              ? (isDark ? AppColors.emerald400 : AppColors.emerald700)
                                              : sc.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  f.name,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isFileSelected
                                        ? const Color(0xFFFFFFFF)
                                        : f.type == 'html'
                                            ? (isDark ? AppColors.primary400 : AppColors.primary700)
                                            : f.type == 'md'
                                                ? (isDark ? AppColors.emerald400 : AppColors.emerald700)
                                                : sc.textSecondary,
                                  ),
                                ),
                              ],
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

  /// 진행 단계 pill 빌드 (기획/디자인/승인/개발)
  List<Widget> _buildProgressPills(Set<String> completedPhases, bool isDark) {
    const phases = ['기획', '디자인', '승인', '개발'];
    return phases.map((phase) {
      final isComplete = completedPhases.contains(phase);
      return Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Container(
          width: 10,
          height: 4,
          decoration: BoxDecoration(
            color: isComplete
                ? AppColors.emerald400
                : (isDark ? AppColors.slate700 : AppColors.slate200),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildViewer(Project project, List<TaskEntry>? history) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    if (_selectedFile == null && !_showingHistory) {
      return Container(
        color: sc.scaffoldBg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.document, size: 48, color: sc.border),
              const SizedBox(height: 16),
              Text('산출물을 선택하세요', style: TextStyle(fontWeight: FontWeight.w600, color: sc.textTertiary)),
              const SizedBox(height: 4),
              Text('왼쪽 목록에서 파일을 클릭하면 이 영역에 표시됩니다', style: TextStyle(fontSize: 11, color: sc.textTertiary)),
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
          decoration: BoxDecoration(
            color: sc.cardBg,
            border: Border(bottom: BorderSide(color: sc.border)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primary500.withValues(alpha: 0.2) : AppColors.primary100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _showingHistory ? '이력' : (_selectedFile?.name ?? ''),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.primary400 : AppColors.primary700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _showingHistory ? '프로젝트 이력 타임라인' : (_selectedTaskSlug ?? ''),
                style: TextStyle(fontSize: 11, color: sc.textTertiary),
              ),
              const Spacer(),
              if (!_showingHistory && _selectedFile != null)
                IconButton(
                  icon: Icon(FluentIcons.open_in_new_window, size: 14, color: sc.textTertiary),
                  onPressed: () {
                    if (_selectedFile != null && File(_selectedFile!.absolutePath).existsSync()) {
                      Process.run('cmd', ['/c', 'start', '', _selectedFile!.absolutePath]);
                    }
                  },
                ),
              IconButton(
                icon: Icon(FluentIcons.clear, size: 14, color: sc.textTertiary),
                onPressed: () => setState(() {
                  _selectedFile = null;
                  _selectedTaskSlug = null;
                  _showingHistory = false;
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

        // Decision bar (산출물 보기 시에만)
        if (_selectedTaskSlug != null && !_showingHistory)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: sc.cardBg,
              border: Border(top: BorderSide(color: sc.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextBox(
                    controller: _commentController,
                    placeholder: '코멘트를 입력하세요...',
                    style: TextStyle(fontSize: 13, color: sc.textPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Button(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      isDark ? AppColors.rose400.withValues(alpha: 0.15) : AppColors.red50,
                    ),
                    foregroundColor: WidgetStatePropertyAll(
                      isDark ? AppColors.rose400 : AppColors.red600,
                    ),
                    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  onPressed: _submittingDecision ? null : () => _submitDecision('반려', project, history),
                  child: Text('반려', style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? AppColors.rose400 : AppColors.red600,
                  )),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(isDark ? AppColors.primary500 : AppColors.primary600),
                    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  onPressed: _submittingDecision ? null : () => _submitDecision('승인', project, history),
                  child: const Text('승인', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFFFFFFF))),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // _buildContent에서 사용하는 변수를 멤버로 캐시
  late Project project;
  late List<TaskEntry>? history;

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

  String _getTaskName(String slug, List<TaskEntry>? history) {
    if (history == null) return '';
    for (final entry in history) {
      final id = entry.id ?? entry.slug;
      if (slug.contains(id) || slug.contains(entry.slug)) {
        return entry.name;
      }
    }
    return '';
  }

  Set<String> _getTaskPhases(String slug, List<TaskEntry>? history) {
    if (history == null) return {};
    for (final entry in history) {
      final id = entry.id ?? entry.slug;
      if (slug.contains(id) || slug.contains(entry.slug)) {
        return entry.logs
            .where((log) => log.status == '완료' || log.status == '승인')
            .map((log) => log.phase)
            .toSet();
      }
    }
    return {};
  }
}
