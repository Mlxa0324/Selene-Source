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
  final int episodeIndex; // 新增：集数索引，用于排序
  final String cover;
  double progress;
  DownloadStatus status;
  final String savePath;
  final DateTime createdAt;
  int totalSegments;
  int downloadedSegments;
  String? error;
  int? fileSize; // 总大小（字节）
  
  // 运行时属性
  double speed = 0; // 下载速度 (字节/秒)
  int currentSize = 0; // 已下载大小 (字节)

  DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.subtitle,
    required this.episodeIndex,
    required this.cover,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    required this.savePath,
    required this.createdAt,
    this.totalSegments = 0,
    this.downloadedSegments = 0,
    this.error,
    this.fileSize,
    this.speed = 0,
    this.currentSize = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'subtitle': subtitle,
      'episodeIndex': episodeIndex,
      'cover': cover,
      'progress': progress,
      'status': status.index,
      'savePath': savePath,
      'createdAt': createdAt.toIso8601String(),
      'totalSegments': totalSegments,
      'downloadedSegments': downloadedSegments,
      'error': error,
      'fileSize': fileSize,
      // 不持久化 speed 和 currentSize，因为它们是运行时的
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'],
      url: json['url'],
      title: json['title'],
      subtitle: json['subtitle'],
      episodeIndex: json['episodeIndex'] ?? 0,
      cover: json['cover'],
      progress: (json['progress'] ?? 0.0).toDouble(),
      status: DownloadStatus.values[json['status'] ?? 0],
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
    double? speed,
    int? currentSize,
    int? episodeIndex,
  }) {
    return DownloadTask(
      id: id,
      url: url,
      title: title,
      subtitle: subtitle,
      episodeIndex: episodeIndex ?? this.episodeIndex,
      cover: cover,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      savePath: savePath,
      createdAt: createdAt,
      totalSegments: totalSegments ?? this.totalSegments,
      downloadedSegments: downloadedSegments ?? this.downloadedSegments,
      error: error ?? this.error,
      fileSize: fileSize ?? this.fileSize,
      speed: speed ?? this.speed,
      currentSize: currentSize ?? this.currentSize,
    );
  }
}
