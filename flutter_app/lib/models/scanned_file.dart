class ScannedFile {
  final String name;
  final String relativePath;
  final String absolutePath;
  final String type; // html, md, json, other
  final int size;
  final DateTime modifiedAt;
  final List<ScannedFile> versions; // 이전 버전들 (v1, v2, ...) 오름차순

  const ScannedFile({
    required this.name,
    required this.relativePath,
    required this.absolutePath,
    required this.type,
    required this.size,
    required this.modifiedAt,
    this.versions = const [],
  });
}

class ScannedTask {
  final String slug;
  final List<ScannedFile> files;
  final bool hasSpec;

  const ScannedTask({
    required this.slug,
    required this.files,
    required this.hasSpec,
  });
}
