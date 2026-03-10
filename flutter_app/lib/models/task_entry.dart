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

class TaskEntry {
  final String slug;
  final String name;
  final List<TaskLog> logs;
  final List<String>? reviews;
  final String? spec;
  final String? id;
  final String? path;

  const TaskEntry({
    required this.slug,
    required this.name,
    required this.logs,
    this.reviews,
    this.spec,
    this.id,
    this.path,
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
      };

  String get lastStatus {
    if (logs.isEmpty) return '미확인';
    return logs.last.status;
  }

  String get lastPhase {
    if (logs.isEmpty) return '';
    return logs.last.phase;
  }
}
