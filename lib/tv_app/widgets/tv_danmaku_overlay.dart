import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/tv_app/services/tv_danmaku_service.dart';

/// TV 专属弹幕叠层。
///
/// TV 全屏播放器通过该组件承载 `canvas_danmaku`，
/// 保持与普通端相同的渲染内核，但不复用普通端页面文件。
class TvDanmakuOverlay extends StatelessWidget {
  /// 创建 TV 专属弹幕叠层。
  const TvDanmakuOverlay({
    super.key,
    required this.settings,
    required this.playbackSpeed,
    required this.overlayVersion,
    this.currentEpisodeId,
    this.onControllerCreated,
  });

  /// 当前弹幕设置。
  final DanmakuSettings settings;

  /// 当前播放器倍速。
  final double playbackSpeed;

  /// 弹幕视口版本。
  ///
  /// 切集、换源或手动匹配成功后递增，用来强制刷新底层弹幕视图。
  final int overlayVersion;

  /// 当前命中的弹幕剧集 ID。
  final int? currentEpisodeId;

  /// 底层弹幕控制器创建回调。
  final ValueChanged<DanmakuController>? onControllerCreated;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layerHeight = constraints.maxHeight * settings.displayArea;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: layerHeight,
              child: DanmakuScreen(
                key: ValueKey(
                  'tv-danmaku-screen-${currentEpisodeId ?? 'none'}-$overlayVersion',
                ),
                createdController: (controller) {
                  onControllerCreated?.call(controller);
                },
                option: TvDanmakuService.buildDanmakuOption(
                  settings,
                  playbackSpeed: playbackSpeed,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
