/// .claude 폴더 내 파일/디렉토리 트리 엔트리
class ClaudeFileEntry {
  final String name;
  final String relativePath;
  final String absolutePath;
  final bool isDirectory;
  final List<ClaudeFileEntry> children;

  const ClaudeFileEntry({
    required this.name,
    required this.relativePath,
    required this.absolutePath,
    required this.isDirectory,
    this.children = const [],
  });
}
