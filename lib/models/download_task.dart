enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
}

class DownloadTask {
  final String id;
  final String url;
  final String title;
  final String subtitle;
  final String cover;
  double progress;
  DownloadStatus status;
  final String savePath;
  final DateTime createdAt;
  int totalSegments;
  int downloadedSegments;
  String? error;
  int? fileSize; // 文件大小（字节）

  DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.subtitle,
    required this.cover,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    required this.savePath,
    required this.createdAt,
    this.totalSegments = 0,
    this.downloadedSegments = 0,
    this.error,
    this.fileSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'subtitle': subtitle,
      'cover': cover,
      'progress': progress,
      'status': status.index,
      'savePath': savePath,
      'createdAt': createdAt.toIso8601String(),
      'totalSegments': totalSegments,
      'downloadedSegments': downloadedSegments,
      'error': error,
      'fileSize': fileSize,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'],
      url: json['url'],
      title: json['title'],
      subtitle: json['subtitle'],
      cover: json['cover'],
      progress: json['progress'],
      status: DownloadStatus.values[json['status']],
      savePath: json['savePath'],
      createdAt: DateTime.parse(json['createdAt']),
      totalSegments: json['totalSegments'] ?? 0,
      downloadedSegments: json['downloadedSegments'] ?? 0,
      error: json['error'],
      fileSize: json['fileSize'],
    );
  }

  DownloadTask copyWith({
    double? progress,
    DownloadStatus? status,
    int? totalSegments,
    int? downloadedSegments,
    String? error,
    int? fileSize,
  }) {
    return DownloadTask(
      id: id,
      url: url,
      title: title,
      subtitle: subtitle,
      cover: cover,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      savePath: savePath,
      createdAt: createdAt,
      totalSegments: totalSegments ?? this.totalSegments,
      downloadedSegments: downloadedSegments ?? this.downloadedSegments,
      error: error ?? this.error,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}
