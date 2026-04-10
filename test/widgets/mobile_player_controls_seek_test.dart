import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import 'package:selene/models/player_cached_range.dart';
import 'package:selene/widgets/danmaku_control_icons.dart';
import 'package:selene/widgets/mobile_player_controls.dart';
import 'package:selene/widgets/player_adapter.dart';

void main() {
  testWidgets('notifies parent after a delayed mobile seek completes',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final seekCompleter = Completer<void>();
    final player = _FakePlayerAdapter(seekCompleter: seekCompleter);
    addTearDown(player.dispose);

    Duration? reportedSeekPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobilePlayerControls(
            player: player,
            onControlsVisibilityChanged: (_) {},
            onFullscreenChange: (_) {},
            videoUrl: 'https://example.com/video.m3u8',
            playbackSpeedListenable: ValueNotifier<double>(1.0),
            onSetSpeed: (_) async {},
            onEnterPipMode: () async {},
            isPipMode: false,
            onSeek: (position) {
              reportedSeekPosition = position;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final progressBar = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MobileVideoProgressBar',
    );
    expect(progressBar, findsOneWidget);

    final rect = tester.getRect(progressBar);
    final tap = Offset(rect.left + rect.width * 0.75, rect.center.dy);

    await tester.tapAt(tap);
    await tester.pump();

    expect(seekCompleter.isCompleted, isFalse);
    expect(reportedSeekPosition, isNull);

    seekCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(reportedSeekPosition, isNotNull);
    expect(reportedSeekPosition, equals(player.state.position));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
      'notifies parent asynchronously after dragging the mobile progress bar',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final player = _FakePlayerAdapter();
    addTearDown(player.dispose);

    Duration? reportedSeekPosition;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobilePlayerControls(
            player: player,
            onControlsVisibilityChanged: (_) {},
            onFullscreenChange: (_) {},
            videoUrl: 'https://example.com/video.m3u8',
            playbackSpeedListenable: ValueNotifier<double>(1.0),
            onSetSpeed: (_) async {},
            onEnterPipMode: () async {},
            isPipMode: false,
            onSeek: (position) {
              reportedSeekPosition = position;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final progressBar = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MobileVideoProgressBar',
    );
    expect(progressBar, findsOneWidget);

    final rect = tester.getRect(progressBar);
    final start = Offset(rect.left + rect.width * 0.25, rect.center.dy);
    final end = Offset(rect.left + rect.width * 0.75, rect.center.dy);

    await tester.dragFrom(start, end - start);
    await tester.pump();

    expect(reportedSeekPosition, isNull);

    await tester.pump(const Duration(milliseconds: 1));
    expect(reportedSeekPosition, isNotNull);
    expect(reportedSeekPosition, equals(player.state.position));
    expect(reportedSeekPosition, greaterThan(const Duration(minutes: 1)));

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('notifies speed changes during direct long press rate control',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final player = _FakePlayerAdapter();
    addTearDown(player.dispose);
    final playbackSpeed = ValueNotifier<double>(1.0);
    addTearDown(playbackSpeed.dispose);
    final reportedSpeeds = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobilePlayerControls(
            player: player,
            onControlsVisibilityChanged: (_) {},
            onFullscreenChange: (_) {},
            videoUrl: 'https://example.com/video.m3u8',
            playbackSpeedListenable: playbackSpeed,
            onSetSpeed: (speed) async {
              reportedSpeeds.add(speed);
              playbackSpeed.value = speed;
              await player.setRate(speed);
            },
            onEnterPipMode: () async {},
            isPipMode: false,
            directLongPressRateControlOverride: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final gestureDetector = tester
        .widgetList<GestureDetector>(find.byType(GestureDetector))
        .firstWhere((widget) => widget.onLongPressStart != null);

    gestureDetector.onLongPressStart!(
      const LongPressStartDetails(globalPosition: Offset(50, 400)),
    );
    await tester.pump();

    expect(reportedSpeeds, contains(2.0));
    expect(player.state.rate, 2.0);

    gestureDetector.onLongPressEnd!(
      const LongPressEndDetails(globalPosition: Offset(50, 400)),
    );
    await tester.pump();

    expect(reportedSpeeds, containsAllInOrder([2.0, 1.0]));
    expect(player.state.rate, 1.0);
  });

  testWidgets(
      'forward ten seconds does not reuse an expired relative seek target',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final player = _FakePlayerAdapter(emitSeekPositionToStream: false);
    addTearDown(player.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobilePlayerControls(
            player: player,
            onControlsVisibilityChanged: (_) {},
            onFullscreenChange: (_) {},
            videoUrl: 'https://example.com/video.m3u8',
            playbackSpeedListenable: ValueNotifier<double>(1.0),
            onSetSpeed: (_) async {},
            onEnterPipMode: () async {},
            isPipMode: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    player.emitPosition(const Duration(minutes: 3));
    await tester.pump();

    final forwardSeekGestureFinder = find.ancestor(
      of: find.byType(ForwardTenIcon),
      matching: find.byType(GestureDetector),
    );
    final forwardSeekGesture =
        tester.widget<GestureDetector>(forwardSeekGestureFinder.first);

    forwardSeekGesture.onTap!.call();
    await tester.pump();

    expect(player.seekCalls.last, const Duration(minutes: 3, seconds: 10));

    await tester.pump(const Duration(seconds: 6));
    player.emitPosition(const Duration(minutes: 5));
    await tester.pump();

    forwardSeekGesture.onTap!.call();
    await tester.pump();

    expect(player.seekCalls.last, const Duration(minutes: 5, seconds: 10));
  });

  testWidgets(
      'mobile progress bar increases touch height without changing control type',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final player = _FakePlayerAdapter();
    addTearDown(player.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobilePlayerControls(
            player: player,
            onControlsVisibilityChanged: (_) {},
            onFullscreenChange: (_) {},
            videoUrl: 'https://example.com/video.m3u8',
            playbackSpeedListenable: ValueNotifier<double>(1.0),
            onSetSpeed: (_) async {},
            onEnterPipMode: () async {},
            isPipMode: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final progressBar = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MobileVideoProgressBar',
    );

    expect(progressBar, findsOneWidget);
    expect(tester.getSize(progressBar).height, 36);
  });
}

class _FakePlayerAdapter implements PlayerAdapter {
  _FakePlayerAdapter({
    this.seekCompleter,
    this.emitSeekPositionToStream = true,
  })  : _stream = _FakePlayerStream(),
        _state = _FakePlayerState();

  final _FakePlayerStream _stream;
  final _FakePlayerState _state;
  final Completer<void>? seekCompleter;
  final bool emitSeekPositionToStream;
  final List<Duration> seekCalls = <Duration>[];

  @override
  PlayerAdapterStream get stream => _stream;

  @override
  PlayerAdapterState get state => _state;

  @override
  Widget buildVideo(
    BuildContext context, {
    BoxFit fit = BoxFit.contain,
    Key? key,
    Widget Function(mkv.VideoState state)? controls,
  }) {
    return const SizedBox.shrink();
  }

  @override
  Future<void> dispose() async {
    await _stream.dispose();
  }

  @override
  Future<void> pause() async {
    _state.playingValue = false;
    _stream.playingController.add(false);
  }

  @override
  Future<void> play() async {
    _state.playingValue = true;
    _stream.playingController.add(true);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    _state.positionValue = position;
    if (emitSeekPositionToStream) {
      _stream.positionController.add(position);
    }
    if (seekCompleter != null) {
      await seekCompleter!.future;
    }
  }

  @override
  Future<void> setRate(double rate) async {
    _state.rateValue = rate;
    _stream.rateController.add(rate);
  }

  @override
  Future<void> setVolume(double volume) async {
    _state.volumeValue = volume;
    _stream.volumeController.add(volume);
  }

  @override
  Future<void> updateVideoFit(BoxFit fit) async {}

  void emitPosition(Duration position) {
    _state.positionValue = position;
    _stream.positionController.add(position);
  }
}

class _FakePlayerStream implements PlayerAdapterStream {
  final playingController = StreamController<bool>.broadcast();
  final positionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration>.broadcast();
  final bufferController = StreamController<Duration>.broadcast();
  final cachedRangesController =
      StreamController<List<PlayerCachedRange>>.broadcast();
  final completedController = StreamController<bool>.broadcast();
  final volumeController = StreamController<double>.broadcast();
  final rateController = StreamController<double>.broadcast();
  final bufferingController = StreamController<bool>.broadcast();

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
    await cachedRangesController.close();
    await completedController.close();
    await volumeController.close();
    await rateController.close();
    await bufferingController.close();
  }
}

class _FakePlayerState implements PlayerAdapterState {
  bool playingValue = true;
  Duration positionValue = Duration.zero;
  Duration durationValue = const Duration(minutes: 12);
  Duration bufferValue = Duration.zero;
  List<PlayerCachedRange> cachedRangesValue = const [];
  double volumeValue = 100;
  double rateValue = 1.0;
  bool bufferingValue = false;
  double widthValue = 1920;
  double heightValue = 1080;

  @override
  Duration get buffer => bufferValue;

  @override
  bool get buffering => bufferingValue;

  @override
  List<PlayerCachedRange> get cachedRanges => cachedRangesValue;

  @override
  Duration get duration => durationValue;

  @override
  double get height => heightValue;

  @override
  bool get playing => playingValue;

  @override
  Duration get position => positionValue;

  @override
  double get rate => rateValue;

  @override
  double get volume => volumeValue;

  @override
  double get width => widthValue;
}
