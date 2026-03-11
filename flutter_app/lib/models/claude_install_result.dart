/// .claude 설치 결과
class ClaudeInstallResult {
  final bool success;
  final int filesCopied;
  final String? error;
  final List<String> excludedFiles;

  const ClaudeInstallResult({
    required this.success,
    required this.filesCopied,
    this.error,
    this.excludedFiles = const [],
  });
}
