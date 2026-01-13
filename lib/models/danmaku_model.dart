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

/// 弹幕搜索动画结果
class DanmakuSearchAnime {
  final int animeId;
  final String animeTitle;
  final String type;
  final String typeDescription;
  final List<DanmakuSearchEpisode> episodes;
  final int year; // 新增年份字段用于排序

  DanmakuSearchAnime({
    required this.animeId,
    required this.animeTitle,
    required this.type,
    required this.typeDescription,
    required this.episodes,
    this.year = 0,
  });

  factory DanmakuSearchAnime.fromJson(Map<String, dynamic> json) {
    final title = json['animeTitle'] ?? '';
    // 尝试从标题中提取年份，如 "作品名(2024)"
    int extractedYear = json['year'] ?? 0;
    if (extractedYear == 0 && title.isNotEmpty) {
      final regExp = RegExp(r'\((\d{4})\)');
      final match = regExp.firstMatch(title);
      if (match != null) {
        extractedYear = int.tryParse(match.group(1) ?? '0') ?? 0;
      }
    }

    return DanmakuSearchAnime(
      animeId: json['animeId'] ?? 0,
      animeTitle: title,
      type: json['type'] ?? '',
      typeDescription: json['typeDescription'] ?? '',
      year: extractedYear,
      episodes: (json['episodes'] as List<dynamic>?)
              ?.map((e) => DanmakuSearchEpisode.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// 弹幕搜索剧集结果
class DanmakuSearchEpisode {
  final int episodeId;
  final String episodeTitle;

  DanmakuSearchEpisode({
    required this.episodeId,
    required this.episodeTitle,
  });

  factory DanmakuSearchEpisode.fromJson(Map<String, dynamic> json) {
    return DanmakuSearchEpisode(
      episodeId: json['episodeId'] ?? 0,
      episodeTitle: json['episodeTitle'] ?? '',
    );
  }
}

/// 弹幕搜索响应
class DanmakuSearchResult {
  final int errorCode;
  final bool success;
  final String errorMessage;
  final List<DanmakuSearchAnime> animes;

  DanmakuSearchResult({
    required this.errorCode,
    required this.success,
    required this.errorMessage,
    required this.animes,
  });

  factory DanmakuSearchResult.fromJson(Map<String, dynamic> json) {
    return DanmakuSearchResult(
      errorCode: json['errorCode'] ?? 0,
      success: json['success'] ?? false,
      errorMessage: json['errorMessage'] ?? '',
      animes: (json['animes'] as List<dynamic>?)
              ?.map((e) => DanmakuSearchAnime.fromJson(e))
              .toList() ??
          [],
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
  final double scale; // 弹幕缩放
  final double lineSpacing; // 行间距
  final double fontWeight; // 字体粗细
  final double displayArea; // 显示区域 (0.25, 0.5, 0.75, 1.0)
  final bool preventOverlap; // 防止重叠
  final bool syncVideoSpeed; // 同步视频速度
  final bool hideScroll;
  final bool hideTop;
  final bool hideBottom;
  final bool hideColor;

  const DanmakuSettings({
    this.enabled = true,
    this.fontSize = 18,
    this.opacity = 1.0,
    this.duration = 7.0,
    this.scale = 1.0,
    this.lineSpacing = 1.0,
    this.fontWeight = 1.0,
    this.displayArea = 0.5,
    this.preventOverlap = false,
    this.syncVideoSpeed = false,
    this.hideScroll = false,
    this.hideTop = false,
    this.hideBottom = false,
    this.hideColor = false,
  });

  DanmakuSettings copyWith({
    bool? enabled,
    double? fontSize,
    double? opacity,
    double? duration,
    double? scale,
    double? lineSpacing,
    double? fontWeight,
    double? displayArea,
    bool? preventOverlap,
    bool? syncVideoSpeed,
    bool? hideScroll,
    bool? hideTop,
    bool? hideBottom,
    bool? hideColor,
  }) {
    return DanmakuSettings(
      enabled: enabled ?? this.enabled,
      fontSize: fontSize ?? this.fontSize,
      opacity: opacity ?? this.opacity,
      duration: duration ?? this.duration,
      scale: scale ?? this.scale,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      fontWeight: fontWeight ?? this.fontWeight,
      displayArea: displayArea ?? this.displayArea,
      preventOverlap: preventOverlap ?? this.preventOverlap,
      syncVideoSpeed: syncVideoSpeed ?? this.syncVideoSpeed,
      hideScroll: hideScroll ?? this.hideScroll,
      hideTop: hideTop ?? this.hideTop,
      hideBottom: hideBottom ?? this.hideBottom,
      hideColor: hideColor ?? this.hideColor,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'fontSize': fontSize,
        'opacity': opacity,
        'duration': duration,
        'scale': scale,
        'lineSpacing': lineSpacing,
        'fontWeight': fontWeight,
        'displayArea': displayArea,
        'preventOverlap': preventOverlap,
        'syncVideoSpeed': syncVideoSpeed,
        'hideScroll': hideScroll,
        'hideTop': hideTop,
        'hideBottom': hideBottom,
        'hideColor': hideColor,
      };

  factory DanmakuSettings.fromJson(Map<String, dynamic> json) {
    return DanmakuSettings(
      enabled: json['enabled'] ?? true,
      fontSize: (json['fontSize'] ?? 18).toDouble(),
      opacity: (json['opacity'] ?? 1.0).toDouble(),
      duration: (json['duration'] ?? 8.0).toDouble(),
      scale: (json['scale'] ?? 1.0).toDouble(),
      lineSpacing: (json['lineSpacing'] ?? 1.0).toDouble(),
      fontWeight: (json['fontWeight'] ?? 1.0).toDouble(),
      displayArea: (json['displayArea'] ?? 1.0).toDouble(),
      preventOverlap: json['preventOverlap'] ?? false,
      syncVideoSpeed: json['syncVideoSpeed'] ?? false,
      hideScroll: json['hideScroll'] ?? false,
      hideTop: json['hideTop'] ?? false,
      hideBottom: json['hideBottom'] ?? false,
      hideColor: json['hideColor'] ?? false,
    );
  }
}
