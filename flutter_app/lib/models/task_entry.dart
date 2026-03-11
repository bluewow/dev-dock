class TaskLog {
  final String phase;
  final String status;
  final String date;
  final String note;

  const TaskLog({
    required this.phase,
    required this.status,
    required this.date,
    required this.note,
  });

  factory TaskLog.fromJson(Map<String, dynamic> json) {
    return TaskLog(
      phase: json['phase'] as String? ?? '',
      status: json['status'] as String? ?? '',
      date: json['date'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'phase': phase,
        'status': status,
        'date': date,
        'note': note,
      };
}

class TaskDecision {
  final String type;
  final String note;

  const TaskDecision({required this.type, required this.note});

  factory TaskDecision.fromJson(Map<String, dynamic> json) {
    return TaskDecision(
      type: json['type'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'type': type, 'note': note};
}

class TaskSummary {
  final String title;
  final List<String> changes;
  final List<TaskDecision> decisions;
  final int filesChanged;
  final int issues;

  const TaskSummary({
    required this.title,
    required this.changes,
    this.decisions = const [],
    this.filesChanged = 0,
    this.issues = 0,
  });

  factory TaskSummary.fromJson(Map<String, dynamic> json) {
    return TaskSummary(
      title: json['title'] as String? ?? '',
      changes: (json['changes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      decisions: (json['decisions'] as List<dynamic>?)
              ?.map((e) => TaskDecision.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      filesChanged: (json['stats'] as Map<String, dynamic>?)?['files_changed'] as int? ?? 0,
      issues: (json['stats'] as Map<String, dynamic>?)?['issues'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'changes': changes,
        if (decisions.isNotEmpty) 'decisions': decisions.map((e) => e.toJson()).toList(),
        'stats': {'files_changed': filesChanged, 'issues': issues},
      };
}

class TaskEntry {
  final String slug;
  final String name;
  final List<TaskLog> logs;
  final List<String>? reviews;
  final String? spec;
  final String? id;
  final String? path;
  final TaskSummary? summary;

  const TaskEntry({
    required this.slug,
    required this.name,
    required this.logs,
    this.reviews,
    this.spec,
    this.id,
    this.path,
    this.summary,
  });

  factory TaskEntry.fromJson(Map<String, dynamic> json) {
    return TaskEntry(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? json['slug'] as String? ?? '',
      logs: (json['logs'] as List<dynamic>?)
              ?.map((e) => TaskLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      reviews: (json['reviews'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      spec: json['spec'] as String?,
      id: json['id'] as String?,
      path: json['path'] as String?,
      summary: json['summary'] != null
          ? TaskSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'name': name,
        'logs': logs.map((e) => e.toJson()).toList(),
        if (reviews != null) 'reviews': reviews,
        if (spec != null) 'spec': spec,
        if (id != null) 'id': id,
        if (path != null) 'path': path,
        if (summary != null) 'summary': summary!.toJson(),
      };

  String get lastStatus {
    if (logs.isEmpty) return '미확인';
    return logs.last.status;
  }

  String get lastPhase {
    if (logs.isEmpty) return '';
    return logs.last.phase;
  }

  /// summary가 없을 때 logs의 note들로 폴백 요약 생성
  List<String> get fallbackChanges {
    if (summary != null) return summary!.changes;
    return logs
        .where((log) => log.note.isNotEmpty)
        .map((log) => log.note)
        .toList();
  }

  String get summaryTitle {
    if (summary != null && summary!.title.isNotEmpty) return summary!.title;
    return name;
  }
}
