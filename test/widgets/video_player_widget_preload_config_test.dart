import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:selene/config/tv_player_kernel.dart';
import 'package:selene/models/playback_preload.dart';
import 'package:selene/models/player_cached_range.dart';
import 'package:selene/widgets/player_adapter.dart';
import 'package:selene/widgets/player_settings_panel.dart';
import 'package:selene/widgets/video_player_surface.dart';
import 'package:selene/widgets/video_player_widget.dart';

void main() {
  test('video player widget exposes unified playback preload level', () {
    const widget = VideoPlayerWidget(
      isShortDrama: false,
      playbackPreloadLevel: PlaybackPreloadLevel.medium,
    );

    expect(widget.playbackPreloadLevel, PlaybackPreloadLevel.medium);
  });

  test('video player controls are visible by default and can be hidden', () {
    const defaultWidget = VideoPlayerWidget(isShortDrama: false);
    const previewWidget = VideoPlayerWidget(
      isShortDrama: false,
      showControls: false,
      showLoadingIndicator: false,
    );

    expect(defaultWidget.showControls, isTrue);
    expect(defaultWidget.showLoadingIndicator, isTrue);
    expect(previewWidget.showControls, isFalse);
    expect(previewWidget.showLoadingIndicator, isFalse);
  });

  test('video player pip can be disabled for TV playback', () {
    const defaultWidget = VideoPlayerWidget(isShortDrama: false);
    const tvWidget = VideoPlayerWidget(
      isShortDrama: false,
      enablePip: false,
    );

    expect(defaultWidget.enablePip, isTrue);
    expect(tvWidget.enablePip, isFalse);
  });

  test('video player background stays configurable for TV preview', () {
    const defaultWidget = VideoPlayerWidget(isShortDrama: false);
    const previewWidget = VideoPlayerWidget(
      isShortDrama: false,
      backgroundColor: Colors.transparent,
    );

    expect(defaultWidget.backgroundColor, Colors.black);
    expect(previewWidget.backgroundColor, Colors.transparent);
  });

  test('video player surface key stays stable across source changes', () {
    expect(
      buildVideoSurfaceKey(
        surface: VideoPlayerSurface.desktop,
        adapterType: WebViewPlayerAdapter,
        fitType: VideoFitType.contain,
      ),
      'video_desktop_WebViewPlayerAdapter',
    );
  });

  test('prefers exo for android tv desktop network playback only', () {
    expect(
      preferExoForAndroidTvPlayback(
        isAndroid: true,
        isLocal: false,
        surface: VideoPlayerSurface.desktop,
        tvPlayerKernel: TvPlayerKernel.exo,
      ),
      isTrue,
    );

    expect(
      preferExoForAndroidTvPlayback(
        isAndroid: true,
        isLocal: false,
        surface: VideoPlayerSurface.desktop,
        tvPlayerKernel: TvPlayerKernel.webView,
      ),
      isFalse,
    );

    expect(
      preferExoForAndroidTvPlayback(
        isAndroid: true,
        isLocal: true,
        surface: VideoPlayerSurface.desktop,
        tvPlayerKernel: TvPlayerKernel.exo,
      ),
      isFalse,
    );
  });

  test('android tv exo source url prefers original stream over outer proxy',
      () {
    expect(
      resolveAndroidTvExoSourceUrl(
        url:
            'https://proxy.example.com/?url=https%3A%2F%2Fvideo.example.com%2F1.m3u8',
        originalUrl: 'https://video.example.com/1.m3u8',
      ),
      'https://video.example.com/1.m3u8',
    );

    expect(
      resolveAndroidTvExoSourceUrl(
        url: 'https://video.example.com/1.m3u8',
      ),
      'https://video.example.com/1.m3u8',
    );
  });

  test('player async initialization aborts after route disposal', () {
    expect(
      shouldAbortPlayerAsyncAfterAwait(
        mounted: false,
        playerDisposed: false,
      ),
      isTrue,
    );
    expect(
      shouldAbortPlayerAsyncAfterAwait(
        mounted: true,
        playerDisposed: true,
      ),
      isTrue,
    );
    expect(
      shouldAbortPlayerAsyncAfterAwait(
        mounted: true,
        playerDisposed: false,
      ),
      isFalse,
    );
  });

  test('player adapter exposes cached ranges through stream and state',
      () async {
    final stream = _FakePlayerAdapterStream();
    final state = _FakePlayerAdapterState();

    final ranges = [
      const PlayerCachedRange(
        start: Duration.zero,
        end: Duration(minutes: 5),
      ),
    ];

    state.cachedRangesValue = ranges;
    final streamExpectation = expectLater(stream.cachedRanges, emits(ranges));
    stream.cachedRangesController.add(ranges);

    expect(state.cachedRanges, ranges);
    await streamExpectation;

    await stream.dispose();
  });

  testWidgets('video player with null url still creates controller eagerly',
      (tester) async {
    VideoPlayerWidgetController? controller;

    await tester.pumpWidget(
      MaterialApp(
        home: VideoPlayerWidget(
          isShortDrama: false,
          url: null,
          enablePip: false,
          onControllerCreated: (createdController) {
            controller = createdController;
          },
        ),
      ),
    );

    await tester.pump();

    expect(controller, isNotNull);
    expect(controller!.isLoading, isFalse);
    expect(controller!.currentPosition, isNull);
  });

  test('web view HLS html installs telemetry loader without ad filtering', () {
    final html = buildWebViewPlayerHtmlForTest(
      url: 'https://example.com/video.m3u8',
      adFilterEnabled: false,
    );

    expect(html, contains('class CustomHlsJsLoader'));
    expect(html, contains('config.loader = CustomHlsJsLoader'));
    expect(html, contains('emitNetworkSpeedFromStats(stats'));
    expect(html, contains("sendEvent('network_speed'"));
    expect(html, contains('estimateResponseBytes(response)'));
    expect(html, contains('if (adFilterEnabled &&'));
  });
}

class _FakePlayerAdapterStream implements PlayerAdapterStream {
  final playingController = StreamController<bool>.broadcast();
  final positionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration>.broadcast();
  final bufferController = StreamController<Duration>.broadcast();
  final completedController = StreamController<bool>.broadcast();
  final volumeController = StreamController<double>.broadcast();
  final rateController = StreamController<double>.broadcast();
  final bufferingController = StreamController<bool>.broadcast();
  final networkSpeedController = StreamController<int>.broadcast();
  final cachedRangesController =
      StreamController<List<PlayerCachedRange>>.broadcast();

  @override
  Stream<Duration> get buffer => bufferController.stream;

  @override
  Stream<bool> get buffering => bufferingController.stream;

  @override
  Stream<List<PlayerCachedRange>> get cachedRanges =>
      cachedRangesController.stream;

  @override
  Stream<bool> get completed => completedController.stream;

  @override
  Stream<Duration> get duration => durationController.stream;

  @override
  Stream<int> get networkSpeedBytesPerSecond => networkSpeedController.stream;

  @override
  Stream<bool> get playing => playingController.stream;

  @override
  Stream<Duration> get position => positionController.stream;

  @override
  Stream<double> get rate => rateController.stream;

  @override
  Stream<double> get volume => volumeController.stream;

  Future<void> dispose() async {
    await playingController.close();
    await positionController.close();
    await durationController.close();
    await bufferController.close();
    await completedController.close();
    await volumeController.close();
    await rateController.close();
    await bufferingController.close();
    await networkSpeedController.close();
    await cachedRangesController.close();
  }
}

class _FakePlayerAdapterState implements PlayerAdapterState {
  List<PlayerCachedRange> cachedRangesValue = const [];

  @override
  Duration get buffer => Duration.zero;

  @override
  bool get buffering => false;

  @override
  List<PlayerCachedRange> get cachedRanges => cachedRangesValue;

  @override
  int get networkSpeedBytesPerSecond => 0;

  @override
  Duration get duration => const Duration(minutes: 5);

  @override
  double get height => 0;

  @override
  bool get playing => false;

  @override
  Duration get position => Duration.zero;

  @override
  double get rate => 1.0;

  @override
  double get volume => 100;

  @override
  double get width => 0;
}
