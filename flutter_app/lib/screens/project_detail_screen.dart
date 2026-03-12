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

/// 산출물 단계 정보 (파일명 → 의미 있는 라벨)
class _DeliverableStep {
  final ScannedFile file;
  final String icon;
  final String label;
  final int order;
  final Color color;
  final Color colorDark;

  const _DeliverableStep({
    required this.file,
    required this.icon,
    required this.label,
    required this.order,
    required this.color,
    required this.colorDark,
  });

  /// 파일명 패턴으로 단계 매핑
  static _DeliverableStep fromFile(ScannedFile file) {
    final name = file.name.toLowerCase();
    if (name == 'idea.html') {
      return _DeliverableStep(file: file, icon: '💡', label: '분석서', order: 0, color: AppColors.cyan700, colorDark: AppColors.cyan400);
    } else if (name == 'plan.html') {
      return _DeliverableStep(file: file, icon: '📋', label: '기획서', order: 1, color: AppColors.blue700, colorDark: AppColors.blue400);
    } else if (name == 'design.html') {
      return _DeliverableStep(file: file, icon: '🎨', label: '디자인 시안', order: 2, color: AppColors.purple700, colorDark: AppColors.purple400);
    } else if (name == 'spec.md') {
      return _DeliverableStep(file: file, icon: '📄', label: '스펙', order: 3, color: AppColors.emerald700, colorDark: AppColors.emerald400);
    } else if (name == 'context.md') {
      return _DeliverableStep(file: file, icon: '📎', label: '컨텍스트', order: 4, color: AppColors.slate500, colorDark: AppColors.slate400);
    } else {
      // 기타 파일: 파일명 그대로
      return _DeliverableStep(file: file, icon: '📑', label: file.name, order: 5, color: AppColors.slate500, colorDark: AppColors.slate400);
    }
  }
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  String? _selectedTaskSlug;
  ScannedFile? _selectedFile;
  final _webviewController = WebviewController();
  bool _webviewReady = false;
  bool _showingHistory = false;
  StreamSubscription<FileSystemEvent>? _fileWatcher;
  StreamSubscription<FileSystemEvent>? _historyWatcher;
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
      // 렌더링 파이프라인 워밍업: 최소 HTML 로드로 WebView2 엔진을 깨운다
      // 이후 loadUrl 호출은 엔진이 이미 활성화되어 빠르게 렌더링된다
      await _webviewController.loadStringContent(
        '<html><body style="background:#0F172A"></body></html>',
      );
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
        // 단계 순서대로 첫 파일 자동 열기
        final steps = _getSortedSteps(task);
        if (steps.isNotEmpty) {
          _openFile(steps.first.file, task.slug);
        }
        return;
      }
    }
  }

  /// docs/tasks/ 및 docs/history.json 변경 감시 → 스캔 재실행
  Future<void> _startFileWatcher() async {
    final service = ref.read(projectServiceProvider);
    final project = await service.findProject(widget.projectId);
    if (project == null) return;

    void triggerRefresh(FileSystemEvent event) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.read(scanTriggerProvider.notifier).state++;
        }
      });
    }

    // docs/tasks/ 하위 파일 변경 감시
    final tasksDir = Directory(p.join(project.path, 'docs', 'tasks'));
    if (tasksDir.existsSync()) {
      _fileWatcher = tasksDir
          .watch(events: FileSystemEvent.all, recursive: true)
          .listen(triggerRefresh);
    }

    // docs/ 디렉토리 감시 (history.json 변경 감지)
    final docsDir = Directory(p.join(project.path, 'docs'));
    if (docsDir.existsSync()) {
      _historyWatcher = docsDir
          .watch(events: FileSystemEvent.modify)
          .listen(triggerRefresh);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _fileWatcher?.cancel();
    _historyWatcher?.cancel();
    _webMessageSubscription?.cancel();
    _webviewController.dispose();
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

  bool _didAutoPreload = false;

  Widget _buildContent(Project project, List<ScannedTask> tasks, List<TaskEntry>? history) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final filter = ref.watch(taskFilterProvider);

    // 스캔 데이터 로드 완료 후 첫 태스크 자동 프리로드
    if (!_didAutoPreload && _webviewReady && _selectedFile == null && !_showingHistory && tasks.isNotEmpty) {
      _didAutoPreload = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedFile != null) return;
        final firstTask = tasks.first;
        final steps = _getSortedSteps(firstTask);
        if (steps.isNotEmpty) _openFile(steps.first.file, firstTask.slug);
      });
    }

    // 필터 적용 + 최신순 정렬 (역순)
    final filteredTasks = tasks.where((task) {
      if (filter == '전체') return true;
      final status = _getTaskStatus(task.slug, history);
      if (filter == '완료') return status == '완료' || status == '승인' || status == '조건부승인';
      if (filter == '진행중') return status != '완료' && status != '승인' && status != '조건부승인';
      return true;
    }).toList().reversed.toList();

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
        Expanded(child: _buildViewer(project, tasks, history)),
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
                // 단계 순서대로 정렬된 첫 파일 자동 열기
                final steps = _getSortedSteps(task);
                if (steps.isNotEmpty) _openFile(steps.first.file, task.slug);
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
                        StatusBadge(status: lastStatus),
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

  /// 태스크 파일을 단계별로 정렬하여 반환
  List<_DeliverableStep> _getSortedSteps(ScannedTask task) {
    final steps = task.files.map(_DeliverableStep.fromFile).toList();
    steps.sort((a, b) => a.order.compareTo(b.order));
    return steps;
  }

  /// 현재 선택된 파일의 단계 인덱스 반환 (버전 파일도 해당 스텝으로 인식)
  int _currentStepIndex(List<_DeliverableStep> steps) {
    if (_selectedFile == null) return -1;
    return steps.indexWhere((s) =>
        s.file.relativePath == _selectedFile!.relativePath ||
        s.file.versions.any((v) => v.relativePath == _selectedFile!.relativePath));
  }

  /// 버전 파일명에서 버전 번호 추출 (idea-v1.html → "v1")
  String _versionLabel(String filename) {
    final match = RegExp(r'-v(\d+)\.').firstMatch(filename);
    return match != null ? 'v${match.group(1)}' : filename;
  }

  Widget _buildViewer(Project project, List<ScannedTask> tasks, List<TaskEntry>? history) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    // 선택된 태스크의 파일 목록
    final selectedTask = _selectedTaskSlug != null
        ? tasks.where((t) => t.slug == _selectedTaskSlug).firstOrNull
        : null;

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
              Text('왼쪽 목록에서 태스크를 클릭하면 이 영역에 표시됩니다', style: TextStyle(fontSize: 11, color: sc.textTertiary)),
            ],
          ),
        ),
      );
    }

    final steps = selectedTask != null ? _getSortedSteps(selectedTask) : <_DeliverableStep>[];
    final currentIdx = _currentStepIndex(steps);

    return Column(
      children: [
        // Viewer header: 단계별 흐름 네비게이션
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: sc.cardBg,
            border: Border(bottom: BorderSide(color: sc.border)),
          ),
          child: Row(
            children: [
              if (selectedTask != null && !_showingHistory)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _buildFlowSteps(steps, currentIdx, isDark, sc),
                    ),
                  ),
                )
              else if (_showingHistory)
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.primary500.withValues(alpha: 0.2) : AppColors.primary100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '이력',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.primary400 : AppColors.primary700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('프로젝트 이력 타임라인', style: TextStyle(fontSize: 11, color: sc.textTertiary)),
                    ],
                  ),
                )
              else
                const Spacer(),

              // Action buttons
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

        // 이전/다음 네비게이션 바
        if (!_showingHistory && steps.length > 1 && currentIdx >= 0)
          _buildPrevNextBar(steps, currentIdx, isDark, sc),
      ],
    );
  }

  /// 단계별 흐름 스텝 위젯 목록 생성
  List<Widget> _buildFlowSteps(List<_DeliverableStep> steps, int currentIdx, bool isDark, AppSemanticColors sc) {
    final widgets = <Widget>[];
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      final isVersionSelected = step.file.versions.any((v) => v.relativePath == _selectedFile?.relativePath);
      final isBaseActive = i == currentIdx && !isVersionSelected;
      final isStepActive = i == currentIdx; // base 또는 버전 선택 시
      final stepColor = isDark ? step.colorDark : step.color;

      if (i > 0) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text('›', style: TextStyle(fontSize: 14, color: sc.borderSubtle)),
        ));
      }

      // 메인 스텝 칩
      widgets.add(
        GestureDetector(
          onTap: () => _openFile(step.file, _selectedTaskSlug!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isBaseActive
                  ? stepColor.withValues(alpha: isDark ? 0.2 : 0.1)
                  : isStepActive
                      ? stepColor.withValues(alpha: isDark ? 0.08 : 0.05)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(step.icon, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isStepActive ? FontWeight.w700 : FontWeight.w400,
                    color: isStepActive ? stepColor : sc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // 버전 칩 (이전 버전들, 오름차순 v1 → v2)
      for (final vf in step.file.versions) {
        final isVersionActive = _selectedFile?.relativePath == vf.relativePath;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: GestureDetector(
              onTap: () => _openFile(vf, _selectedTaskSlug!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isVersionActive
                      ? stepColor.withValues(alpha: isDark ? 0.2 : 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isVersionActive ? stepColor : sc.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Text(
                  _versionLabel(vf.name),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isVersionActive ? stepColor : sc.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  /// 이전/다음 네비게이션 바
  Widget _buildPrevNextBar(List<_DeliverableStep> steps, int currentIdx, bool isDark, AppSemanticColors sc) {
    final hasPrev = currentIdx > 0;
    final hasNext = currentIdx < steps.length - 1;
    final prevStep = hasPrev ? steps[currentIdx - 1] : null;
    final nextStep = hasNext ? steps[currentIdx + 1] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: sc.cardBg,
        border: Border(top: BorderSide(color: sc.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 이전
          if (hasPrev)
            GestureDetector(
              onTap: () => _openFile(prevStep.file, _selectedTaskSlug!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.chevron_left, size: 10, color: sc.textTertiary),
                  const SizedBox(width: 4),
                  Text(prevStep!.icon, style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                  Text(prevStep.label, style: TextStyle(fontSize: 11, color: sc.textSecondary)),
                ],
              ),
            )
          else
            const SizedBox(),

          // 현재 위치
          Text(
            '${currentIdx + 1} / ${steps.length}',
            style: TextStyle(fontSize: 10, color: sc.textTertiary, fontWeight: FontWeight.w500),
          ),

          // 다음
          if (hasNext)
            GestureDetector(
              onTap: () => _openFile(nextStep.file, _selectedTaskSlug!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(nextStep!.label, style: TextStyle(fontSize: 11, color: isDark ? nextStep.colorDark : nextStep.color, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 3),
                  Text(nextStep.icon, style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 4),
                  Icon(FluentIcons.chevron_right, size: 10, color: isDark ? nextStep.colorDark : nextStep.color),
                ],
              ),
            )
          else
            const SizedBox(),
        ],
      ),
    );
  }

  // ─── Helper Methods ──────────────────────────────────────────────────────

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
            .where((log) => log.status == '완료' || log.status == '승인' || log.status == '조건부승인')
            .map((log) => log.phase)
            .toSet();
      }
    }
    return {};
  }
}
