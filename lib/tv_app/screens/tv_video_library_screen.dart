import 'package:flutter/material.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_video_detail_screen.dart';
import 'package:selene/tv_app/widgets/tv_back_handler.dart';
import 'package:selene/tv_app/widgets/tv_video_grid.dart';

/// TV 视频库列表数据加载函数。
typedef TvVideoLibraryLoader = Future<List<VideoInfo>> Function(
  BuildContext context,
);

/// TV 视频库详情页构建函数。
typedef TvVideoLibraryDetailPageBuilder = Widget Function(VideoInfo videoInfo);

/// TV 独立视频库页面。
///
/// 用于承载播放历史、收藏夹等需要整页浏览的视频列表。
class TvVideoLibraryScreen extends StatefulWidget {
  /// 创建 TV 独立视频库页面。
  const TvVideoLibraryScreen({
    super.key,
    required this.title,
    required this.loadVideos,
    this.buildDetailPage,
  });

  /// 页面标题。
  final String title;

  /// 页面数据加载函数。
  final TvVideoLibraryLoader loadVideos;

  /// 详情页构建函数。
  final TvVideoLibraryDetailPageBuilder? buildDetailPage;

  @override
  State<TvVideoLibraryScreen> createState() => _TvVideoLibraryScreenState();
}

class _TvVideoLibraryScreenState extends State<TvVideoLibraryScreen> {
  /// 列表数据加载任务。
  Future<List<VideoInfo>>? _videosFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _videosFuture ??= widget.loadVideos(context);
  }

  @override
  Widget build(BuildContext context) {
    return TvBackHandler(
      autofocus: true,
      child: Scaffold(
        key: ValueKey('tv-video-library-screen-${widget.title}'),
        backgroundColor: const Color(0xFF10131D),
        body: SafeArea(
          child: FutureBuilder<List<VideoInfo>>(
            future: _videosFuture,
            builder: (context, snapshot) {
              final videos = snapshot.data ?? const <VideoInfo>[];
              final isLoading =
                  snapshot.connectionState != ConnectionState.done;
              return TvVideoGrid(
                title: widget.title,
                videos: videos,
                isLoading: isLoading,
                onVideoPressed: _openVideo,
              );
            },
          ),
        ),
      ),
    );
  }

  /// 打开当前卡片对应的 TV 详情页。
  void _openVideo(VideoInfo videoInfo) {
    final detailPage = widget.buildDetailPage?.call(videoInfo) ??
        TvVideoDetailScreen(videoInfo: videoInfo);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => detailPage,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
