import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;

import '../../player_adapter.dart';
import '../benchmark_player_driver.dart';

class MediaKitBenchmarkDriver extends BaseBenchmarkPlayerDriver {
  MediaKitAdapter? _adapter;

  @override
  Future<void> load(String url) async {
    await _adapter?.dispose();
    _adapter = null;
    resetReadyState();

    final player = mk.Player();
    final adapter = MediaKitAdapter(player);
    _adapter = adapter;

    addSubscription(adapter.stream.position.listen(emitPosition));
    addSubscription(adapter.stream.duration.listen(emitDuration));
    addSubscription(adapter.stream.buffering.listen(emitBuffering));

    await player.open(mk.Media(url), play: false);
    emitPosition(player.state.position);
    emitDuration(player.state.duration);
    emitBuffering(player.state.buffering);
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
