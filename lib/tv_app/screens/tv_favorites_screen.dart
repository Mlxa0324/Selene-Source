import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_video_library_screen.dart';
import 'package:selene/tv_app/services/tv_video_library_service.dart';

/// TV 收藏夹独立页面。
class TvFavoritesScreen extends StatelessWidget {
  /// 创建 TV 收藏夹独立页面。
  const TvFavoritesScreen({
    super.key,
    this.loadVideos,
    this.buildDetailPage,
  });

  /// 收藏夹数据加载函数。
  final TvVideoLibraryLoader? loadVideos;

  /// 详情页构建函数。
  final TvVideoLibraryDetailPageBuilder? buildDetailPage;

  /// 默认收藏夹加载逻辑。
  static Future<List<VideoInfo>> defaultLoadVideos(BuildContext context) {
    return TvVideoLibraryService.loadFavorites(context);
  }

  @override
  Widget build(BuildContext context) {
    return TvVideoLibraryScreen(
      title: '收藏夹',
      loadVideos: loadVideos ?? defaultLoadVideos,
      buildDetailPage: buildDetailPage,
    );
  }
}
