import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_video_library_screen.dart';
import 'package:selene/tv_app/services/tv_video_library_service.dart';

/// TV 播放历史独立页面。
class TvHistoryScreen extends StatelessWidget {
  /// 创建 TV 播放历史独立页面。
  const TvHistoryScreen({
    super.key,
    this.loadVideos,
    this.buildDetailPage,
  });

  /// 播放历史数据加载函数。
  final TvVideoLibraryLoader? loadVideos;

  /// 详情页构建函数。
  final TvVideoLibraryDetailPageBuilder? buildDetailPage;

  /// 默认播放历史加载逻辑。
  static Future<List<VideoInfo>> defaultLoadVideos(BuildContext context) {
    return TvVideoLibraryService.loadHistory(context);
  }

  @override
  Widget build(BuildContext context) {
    return TvVideoLibraryScreen(
      title: '播放历史',
      loadVideos: loadVideos ?? defaultLoadVideos,
      buildDetailPage: buildDetailPage,
    );
  }
}
