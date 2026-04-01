import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/player_benchmark_video_platform_registry.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  group('PlayerBenchmarkVideoPlatformRegistry', () {
    test('captures the original official platform and restores it later', () {
      final originalPlatform = _FakeVideoPlayerPlatform('official');
      final fvpPlatform = _FakeVideoPlayerPlatform('fvp');
      VideoPlayerPlatform.instance = originalPlatform;

      final registry = PlayerBenchmarkVideoPlatformRegistry(
        fvpPlatformFactory: () => fvpPlatform,
      );

      registry.captureOriginalPlatformIfNeeded();
      expect(registry.originalPlatform, same(originalPlatform));

      registry.useFvpVideoPlayer();
      expect(VideoPlayerPlatform.instance, same(fvpPlatform));

      registry.useOfficialVideoPlayer();
      expect(VideoPlayerPlatform.instance, same(originalPlatform));
    });

    test('does not overwrite the first captured official platform', () {
      final originalPlatform = _FakeVideoPlayerPlatform('official');
      final replacementPlatform = _FakeVideoPlayerPlatform('replacement');
      final fvpPlatform = _FakeVideoPlayerPlatform('fvp');
      VideoPlayerPlatform.instance = originalPlatform;

      final registry = PlayerBenchmarkVideoPlatformRegistry(
        fvpPlatformFactory: () => fvpPlatform,
      );

      registry.captureOriginalPlatformIfNeeded();
      VideoPlayerPlatform.instance = replacementPlatform;
      registry.captureOriginalPlatformIfNeeded();

      expect(registry.originalPlatform, same(originalPlatform));
    });

    test('can switch repeatedly without losing the original platform', () {
      final originalPlatform = _FakeVideoPlayerPlatform('official');
      final fvpPlatformA = _FakeVideoPlayerPlatform('fvp-a');
      final fvpPlatformB = _FakeVideoPlayerPlatform('fvp-b');
      var factoryCallCount = 0;
      VideoPlayerPlatform.instance = originalPlatform;

      final registry = PlayerBenchmarkVideoPlatformRegistry(
        fvpPlatformFactory: () {
          factoryCallCount++;
          return factoryCallCount == 1 ? fvpPlatformA : fvpPlatformB;
        },
      );

      registry.captureOriginalPlatformIfNeeded();
      registry.useFvpVideoPlayer();
      expect(VideoPlayerPlatform.instance, same(fvpPlatformA));

      registry.useOfficialVideoPlayer();
      expect(VideoPlayerPlatform.instance, same(originalPlatform));

      registry.useFvpVideoPlayer();
      expect(VideoPlayerPlatform.instance, same(fvpPlatformB));
      expect(registry.originalPlatform, same(originalPlatform));
    });
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  _FakeVideoPlayerPlatform(this.name);

  final String name;

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> init() async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => const Stream.empty();

  @override
  Widget buildView(int playerId) => const SizedBox.shrink();
}
