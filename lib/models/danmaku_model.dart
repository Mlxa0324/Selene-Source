/// 弹幕匹配结果
class DanmakuMatchResult {
  final int errorCode;
  final bool success;
  final String errorMessage;
  final bool isMatched;
  final List<DanmakuMatchItem> matches;

  DanmakuMatchResult({
    required this.errorCode,
    required this.success,
    required this.errorMessage,
    required this.isMatched,
    required this.matches,
  });

  factory DanmakuMatchResult.fromJson(Map<String, dynamic> json) {
    return DanmakuMatchResult(
      errorCode: json['errorCode'] ?? 0,
      success: json['success'] ?? false,
      errorMessage: json['errorMessage'] ?? '',
      isMatched: json['isMatched'] ?? false,
      matches: (json['matches'] as List<dynamic>?)
              ?.map((e) => DanmakuMatchItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// 弹幕匹配项
class DanmakuMatchItem {
  final int episodeId;
  final int animeId;
  final String animeTitle;
  final String episodeTitle;
  final String type;
  final String typeDescription;
  final int shift;
  final String? imageUrl;

  DanmakuMatchItem({
    required this.episodeId,
    required this.animeId,
    required this.animeTitle,
    required this.episodeTitle,
    required this.type,
    required this.typeDescription,
    required this.shift,
    this.imageUrl,
  });

  factory DanmakuMatchItem.fromJson(Map<String, dynamic> json) {
    return DanmakuMatchItem(
      episodeId: json['episodeId'] ?? 0,
      animeId: json['animeId'] ?? 0,
      animeTitle: json['animeTitle'] ?? '',
      episodeTitle: json['episodeTitle'] ?? '',
      type: json['type'] ?? '',
      typeDescription: json['typeDescription'] ?? '',
      shift: json['shift'] ?? 0,
      imageUrl: json['imageUrl'],
    );
  }
}

/// 弹幕列表响应
class DanmakuListResult {
  final int count;
  final List<DanmakuComment> comments;

  DanmakuListResult({
    required this.count,
    required this.comments,
  });

  factory DanmakuListResult.fromJson(Map<String, dynamic> json) {
    return DanmakuListResult(
      count: json['count'] ?? 0,
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => DanmakuComment.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// 单条弹幕数据
class DanmakuComment {
  final int cid;
  final String p; // 时间,类型,颜色,[来源]
  final String m; // 弹幕内容
  final int t;

  // 解析后的字段
  late final double time;
  late final int type; // 1=滚动, 4=底部, 5=顶部
  late final int color;

  DanmakuComment({
    required this.cid,
    required this.p,
    required this.m,
    required this.t,
  }) {
    _parseP();
  }

  void _parseP() {
    final parts = p.split(',');
    time = double.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    type = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    color = int.tryParse(parts.length > 2 ? parts[2] : '16777215') ?? 16777215;
  }

  factory DanmakuComment.fromJson(Map<String, dynamic> json) {
    return DanmakuComment(
      cid: json['cid'] ?? 0,
      p: json['p'] ?? '0,1,16777215',
      m: json['m'] ?? '',
      t: json['t'] ?? 0,
    );
  }
}

/// 弹幕设置
class DanmakuSettings {
  final bool enabled;
  final double fontSize;
  final double opacity;
  final double duration; // 滚动弹幕持续时间（秒）
  final bool hideScroll;
  final bool hideTop;
  final bool hideBottom;

  const DanmakuSettings({
    this.enabled = true,
    this.fontSize = 18,
    this.opacity = 1.0,
    this.duration = 8.0,
    this.hideScroll = false,
    this.hideTop = false,
    this.hideBottom = false,
  });

  DanmakuSettings copyWith({
    bool? enabled,
    double? fontSize,
    double? opacity,
    double? duration,
    bool? hideScroll,
    bool? hideTop,
    bool? hideBottom,
  }) {
    return DanmakuSettings(
      enabled: enabled ?? this.enabled,
      fontSize: fontSize ?? this.fontSize,
      opacity: opacity ?? this.opacity,
      duration: duration ?? this.duration,
      hideScroll: hideScroll ?? this.hideScroll,
      hideTop: hideTop ?? this.hideTop,
      hideBottom: hideBottom ?? this.hideBottom,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'fontSize': fontSize,
        'opacity': opacity,
        'duration': duration,
        'hideScroll': hideScroll,
        'hideTop': hideTop,
        'hideBottom': hideBottom,
      };

  factory DanmakuSettings.fromJson(Map<String, dynamic> json) {
    return DanmakuSettings(
      enabled: json['enabled'] ?? true,
      fontSize: (json['fontSize'] ?? 18).toDouble(),
      opacity: (json['opacity'] ?? 1.0).toDouble(),
      duration: (json['duration'] ?? 8.0).toDouble(),
      hideScroll: json['hideScroll'] ?? false,
      hideTop: json['hideTop'] ?? false,
      hideBottom: json['hideBottom'] ?? false,
    );
  }
}
