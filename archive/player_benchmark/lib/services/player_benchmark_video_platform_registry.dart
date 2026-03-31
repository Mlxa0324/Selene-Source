import 'dart:io' show Platform;

import 'package:fvp/fvp.dart' as fvp;
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

typedef BenchmarkVideoPlatformFactory = VideoPlayerPlatform Function();

class PlayerBenchmarkVideoPlatformRegistry {
  PlayerBenchmarkVideoPlatformRegistry({
    BenchmarkVideoPlatformFactory? fvpPlatformFactory,
  }) : _fvpPlatformFactory = fvpPlatformFactory ?? _defaultFvpPlatformFactory;

  final BenchmarkVideoPlatformFactory _fvpPlatformFactory;

  VideoPlayerPlatform? _originalPlatform;

  VideoPlayerPlatform? get originalPlatform => _originalPlatform;

  void captureOriginalPlatformIfNeeded() {
    _originalPlatform ??= VideoPlayerPlatform.instance;
  }

  VideoPlayerPlatform useOfficialVideoPlayer() {
    captureOriginalPlatformIfNeeded();
    final originalPlatform = _originalPlatform;
    if (originalPlatform != null) {
      VideoPlayerPlatform.instance = originalPlatform;
    }
    return VideoPlayerPlatform.instance;
  }

  VideoPlayerPlatform useFvpVideoPlayer() {
    captureOriginalPlatformIfNeeded();
    final fvpPlatform = _fvpPlatformFactory();
    VideoPlayerPlatform.instance = fvpPlatform;
    return fvpPlatform;
  }

  static VideoPlayerPlatform _defaultFvpPlatformFactory() {
    fvp.registerWith(options: {
      'platforms': [Platform.operatingSystem],
    });
    return VideoPlayerPlatform.instance;
  }
}
