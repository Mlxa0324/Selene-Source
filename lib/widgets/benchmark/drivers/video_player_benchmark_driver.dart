import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as vp;

import '../../../services/player_benchmark_video_platform_registry.dart';
import '../../player_adapter.dart';
import '../benchmark_player_driver.dart';

class VideoPlayerBenchmarkDriver extends BaseBenchmarkPlayerDriver {
  VideoPlayerBenchmarkDriver({
    required PlayerBenchmarkVideoPlatformRegistry videoPlatformRegistry,
  }) : _videoPlatformRegistry = videoPlatformRegistry;

  final PlayerBenchmarkVideoPlatformRegistry _videoPlatformRegistry;

  VideoPlayerAdapter? _adapter;

  @override
  Future<void> load(String url) async {
    await _adapter?.dispose();
    _adapter = null;
    resetReadyState();

    _videoPlatformRegistry.useOfficialVideoPlayer();
    final controller = vp.VideoPlayerController.networkUrl(Uri.parse(url));
    final adapter = VideoPlayerAdapter(controller);
    _adapter = adapter;

    addSubscription(adapter.stream.position.listen(emitPosition));
    addSubscription(adapter.stream.buffering.listen(emitBuffering));

    await controller.initialize();
    emitPosition(controller.value.position);
    emitBuffering(controller.value.isBuffering);
    markReady();
  }

  @override
  Future<void> play() async {
    await _adapter?.play();
  }

  @override
  Future<void> pause() async {
    await _adapter?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _adapter?.seek(position);
  }

  @override
  Widget buildView(BuildContext context, {Key? key}) {
    final adapter = _adapter;
    if (adapter == null) {
      return const SizedBox.shrink();
    }
    return adapter.buildVideo(context, key: key);
  }

  @override
  Future<void> dispose() async {
    await _adapter?.dispose();
    _adapter = null;
    await disposeBase();
  }
}
