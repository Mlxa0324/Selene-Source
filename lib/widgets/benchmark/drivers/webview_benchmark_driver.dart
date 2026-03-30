import 'dart:async';

import 'package:flutter/material.dart';

import '../../player_adapter.dart';
import '../benchmark_player_driver.dart';

class WebViewBenchmarkDriver extends BaseBenchmarkPlayerDriver {
  WebViewPlayerAdapter? _adapter;

  @override
  Future<void> load(String url) async {
    await _adapter?.dispose();
    resetReadyState();

    final adapter = WebViewPlayerAdapter(
      url: url,
      onReady: markReady,
      seekBoostEnabled: true,
    );
    _adapter = adapter;

    addSubscription(adapter.stream.position.listen(emitPosition));
    addSubscription(adapter.stream.buffering.listen(emitBuffering));
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
