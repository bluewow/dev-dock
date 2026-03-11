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

  String get _lastStatus {
    if (widget.history == null || widget.history!.isEmpty) return '비활성';
    final last = widget.history!.last;
    return last.lastStatus;
  }

  /// 가장 최근 로그가 있는 태스크 엔트리를 반환
  TaskEntry? get _latestEntry {
    if (widget.history == null || widget.history!.isEmpty) return null;
    TaskEntry? latest;
    DateTime? latestDate;
    for (final entry in widget.history!) {
      if (entry.logs.isEmpty) continue;
      final log = entry.logs.last;
      final date = DateTime.tryParse(log.date);
      if (date != null && (latestDate == null || date.isAfter(latestDate))) {
        latestDate = date;
        latest = entry;
      }
    }
    return latest ?? (widget.history!.isNotEmpty ? widget.history!.last : null);
  }

  /// 상대 시간 문자열 생성
  String _relativeTime(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}주 전';
    return '${(diff.inDays / 30).floor()}개월 전';
  }

  @override
  Widget build(BuildContext context) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final dotColor = AppColors.dotColor(widget.project.color);

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

              const SizedBox(height: 4),

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

              // Recent activity (expanded to fill)
              if (_latestEntry != null) ...[
                const SizedBox(height: 10),
                Expanded(child: _buildRecentActivity(sc, isDark)),
              ] else
                const Expanded(child: SizedBox()),

              // Task list
              if (_taskCount > 0) ...[
                const SizedBox(height: 8),
                _buildTaskList(sc, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 마침표 뒤에 줄바꿈을 넣어 가독성 향상
  String _formatNote(String note) {
    return note.replaceAll('. ', '.\n');
  }

  Widget _buildRecentActivity(AppSemanticColors sc, bool isDark) {
    final entry = _latestEntry!;
    final log = entry.logs.last;
    final timeStr = _relativeTime(log.date);
    final taskName = entry.name.isNotEmpty ? entry.name : entry.slug;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.slate700.withValues(alpha: 0.5) : AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 태스크명 + 시간
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.statusText(log.status, isDark: isDark),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  taskName,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sc.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (timeStr.isNotEmpty)
                Text(timeStr, style: TextStyle(fontSize: 10, color: sc.textTertiary)),
            ],
          ),
          const SizedBox(height: 4),
          // 단계 + 상태
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.statusBg(log.phase, isDark: isDark),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.phase,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.statusText(log.phase, isDark: isDark)),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                log.status,
                style: TextStyle(fontSize: 10, color: AppColors.statusText(log.status, isDark: isDark), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          // 설명 (남은 공간 채움, 마침표 기준 줄바꿈)
          if (log.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                _formatNote(log.note),
                style: TextStyle(fontSize: 10, color: sc.textSecondary, height: 1.5),
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskList(AppSemanticColors sc, bool isDark) {
    const allPhases = ['기획', '디자인', '승인', '개발'];
    final entries = widget.history!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(entries.length, (i) {
        final entry = entries[i];
        final seq = (i + 1).toString().padLeft(3, '0');
        final name = entry.slug;
        final donePhases = entry.logs
            .where((l) => l.status == '완료' || l.status == '승인' || l.status == '조건부승인')
            .map((l) => l.phase)
            .toSet();

        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              Text(
                '$seq.',
                style: TextStyle(fontSize: 10, color: sc.textTertiary, fontFamily: 'Consolas'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(fontSize: 10, color: sc.textSecondary, fontFamily: 'Consolas'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // 단계별 미니 pill
              ...allPhases.map((phase) {
                final done = donePhases.contains(phase);
                return Padding(
                  padding: const EdgeInsets.only(right: 1),
                  child: Container(
                    width: 6,
                    height: 3,
                    decoration: BoxDecoration(
                      color: done ? AppColors.emerald400 : (isDark ? AppColors.slate700 : AppColors.slate200),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }),
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
