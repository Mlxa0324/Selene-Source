import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/player_benchmark_models.dart';
import '../../services/player_benchmark_video_platform_registry.dart';
import 'benchmark_player_driver.dart';
import 'drivers/fvp_benchmark_driver.dart';
import 'drivers/media_kit_benchmark_driver.dart';
import 'drivers/video_player_benchmark_driver.dart';
import 'drivers/webview_benchmark_driver.dart';

typedef BenchmarkPlayerDriverFactory = BenchmarkPlayerDriver Function(
    BenchmarkPlayerBackend backend);

class BenchmarkPlayerHost extends StatefulWidget {
  const BenchmarkPlayerHost({
    super.key,
    required this.backend,
    required this.url,
    required this.generation,
    required this.videoPlatformRegistry,
    this.driverFactory,
    this.onDriverChanged,
  });

  final BenchmarkPlayerBackend backend;
  final String url;
  final int generation;
  final PlayerBenchmarkVideoPlatformRegistry videoPlatformRegistry;
  final BenchmarkPlayerDriverFactory? driverFactory;
  final ValueChanged<BenchmarkPlayerDriver>? onDriverChanged;

  @override
  State<BenchmarkPlayerHost> createState() => _BenchmarkPlayerHostState();
}

class _BenchmarkPlayerHostState extends State<BenchmarkPlayerHost> {
  BenchmarkPlayerDriver? _driver;
  StreamSubscription<bool>? _readySubscription;

  @override
  void initState() {
    super.initState();
    _replaceDriver();
  }

  @override
  void didUpdateWidget(covariant BenchmarkPlayerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.backend != oldWidget.backend ||
        widget.url != oldWidget.url ||
        widget.generation != oldWidget.generation) {
      unawaited(_replaceDriver());
    }
  }

  Future<void> _replaceDriver() async {
    await _readySubscription?.cancel();
    await _driver?.dispose();

    final driver =
        (widget.driverFactory ?? _defaultDriverFactory)(widget.backend);
    _driver = driver;
    widget.onDriverChanged?.call(driver);

    _readySubscription = driver.readyStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    if (mounted) {
      setState(() {});
    }
    await driver.load(widget.url);
  }

  BenchmarkPlayerDriver _defaultDriverFactory(
    BenchmarkPlayerBackend backend,
  ) {
    switch (backend) {
      case BenchmarkPlayerBackend.webView:
        return WebViewBenchmarkDriver();
      case BenchmarkPlayerBackend.videoPlayer:
        return VideoPlayerBenchmarkDriver(
          videoPlatformRegistry: widget.videoPlatformRegistry,
        );
      case BenchmarkPlayerBackend.mediaKit:
        return MediaKitBenchmarkDriver();
      case BenchmarkPlayerBackend.fvp:
        return FvpBenchmarkDriver(
          videoPlatformRegistry: widget.videoPlatformRegistry,
        );
    }
  }

  @override
  void dispose() {
    unawaited(_readySubscription?.cancel());
    unawaited(_driver?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driver = _driver;
    if (driver == null) {
      return const SizedBox.shrink();
    }
    return driver.buildView(context);
  }
}
