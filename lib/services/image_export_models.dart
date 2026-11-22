class ExportResult {
  final bool success;
  final String filePath;
  final String message;
  final bool canShare;

  const ExportResult({
    required this.success,
    required this.filePath,
    required this.message,
    this.canShare = false,
  });
}
