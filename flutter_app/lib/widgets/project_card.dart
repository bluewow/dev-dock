import 'package:fluent_ui/fluent_ui.dart';
import '../models/project.dart';
import '../models/task_entry.dart';
import '../theme/app_theme.dart';

class ProjectCard extends StatefulWidget {
  final Project project;
  final List<TaskEntry>? history;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ProjectCard({
    super.key,
    required this.project,
    this.history,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hovering = false;

  int get _taskCount => widget.history?.length ?? 0;

  int get _completedCount => widget.history?.where((t) {
        final last = t.logs.isNotEmpty ? t.logs.last : null;
        return last != null && last.status == '완료';
      }).length ?? 0;

  String get _lastStatus {
    if (widget.history == null || widget.history!.isEmpty) return '비활성';
    final last = widget.history!.last;
    return last.lastStatus;
  }

  String get _latestActivity {
    if (widget.history == null || widget.history!.isEmpty) return '';
    final last = widget.history!.last;
    if (last.logs.isEmpty) return '';
    final log = last.logs.last;
    return '${last.name.isNotEmpty ? last.name : last.slug} - ${log.phase} ${log.status}';
  }

  @override
  Widget build(BuildContext context) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final dotColor = AppColors.dotColor(widget.project.color);
    final pct = _taskCount == 0 ? 0.0 : _completedCount / _taskCount;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: sc.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering
                  ? (isDark ? AppColors.primary500 : AppColors.primary200)
                  : sc.border,
            ),
            boxShadow: isDark
                ? null
                : _hovering
                    ? [BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]
                    : [BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.project.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _hovering
                            ? (isDark ? AppColors.primary400 : AppColors.primary700)
                            : sc.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusBadge(status: _lastStatus),
                  if (_hovering)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: widget.onDelete,
                        child: Icon(FluentIcons.delete, size: 14, color: AppColors.red500.withValues(alpha: 0.7)),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Path
              Text(
                widget.project.path,
                style: TextStyle(
                  fontSize: 11,
                  color: sc.textTertiary,
                  fontFamily: 'Consolas',
                ),
                overflow: TextOverflow.ellipsis,
              ),

              // Progress bar
              if (_taskCount > 0) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('진행률', style: TextStyle(fontSize: 11, color: sc.textTertiary)),
                    Text(
                      '$_completedCount/$_taskCount',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? AppColors.primary400 : AppColors.primary600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: ProgressBar(
                    value: pct * 100,
                    backgroundColor: isDark ? AppColors.slate700 : AppColors.slate100,
                    activeColor: dotColor,
                  ),
                ),
              ],

              // Latest activity
              if (_latestActivity.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: sc.borderSubtle)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.amber400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _latestActivity,
                          style: TextStyle(fontSize: 11, color: sc.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.statusBg(status, isDark: isDark),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.statusText(status, isDark: isDark),
        ),
      ),
    );
  }
}
