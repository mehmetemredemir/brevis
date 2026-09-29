/// Kotlin `com.leti.brevis.ai.ModelDownloadState` ile birebir eşleşir.
library;

enum ModelStatus { notDownloaded, downloading, ready, error }

ModelStatus _statusFromString(String raw) {
  switch (raw) {
    case 'NOT_DOWNLOADED':
      return ModelStatus.notDownloaded;
    case 'DOWNLOADING':
      return ModelStatus.downloading;
    case 'READY':
      return ModelStatus.ready;
    case 'ERROR':
      return ModelStatus.error;
    default:
      return ModelStatus.notDownloaded;
  }
}

class ModelDownloadState {
  final ModelStatus status;
  final int progressPercent;
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;

  const ModelDownloadState({
    this.status = ModelStatus.notDownloaded,
    this.progressPercent = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  factory ModelDownloadState.fromJson(Map<String, dynamic> json) => ModelDownloadState(
        status: _statusFromString(json['status'] as String? ?? 'NOT_DOWNLOADED'),
        progressPercent: json['progressPercent'] ?? 0,
        downloadedBytes: json['downloadedBytes'] ?? 0,
        totalBytes: json['totalBytes'] ?? 0,
        errorMessage: json['errorMessage'] as String?,
      );

  String get downloadedSizeLabel => _formatBytes(downloadedBytes);
  String get totalSizeLabel => _formatBytes(totalBytes);

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    if (mb < 1024) return '${mb.toStringAsFixed(0)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }
}
