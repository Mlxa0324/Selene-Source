import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import 'package:selene/models/player_cached_range.dart';
import 'package:selene/widgets/danmaku_control_icons.dart';
import 'package:selene/widgets/mobile_player_controls.dart';
import 'package:selene/widgets/player_adapter.dart';

void main() {
  testWidgets('double tap keeps hidden mobile controls after pausing playback',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final player = _FakePlayerAdapter(playing: true);
    addTearDown(player.dispose);

    final visibilityEvents = <bool>[];
    var pauseCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobilePlayerControls(
            player: player,
            onControlsVisibilityChanged: visibilityEvents.add,
            onFullscreenChange: (_) {},
            onPause: () => pauseCount++,
            videoUrl: 'https://example.com/video.m3u8',
            playbackSpeedListenable: ValueNotifier<double>(1.0),
            onSetSpeed: (_) async {},
            onEnterPipMode: () async {},
            isPipMode: false,
          ),
        ),
      ),
    );

    await tester.pump();
    visibilityEvents.clear();

    const tapPoint = Offset(24, 300);
    final hideGesture = await tester.startGesture(tapPoint);
    await hideGesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(visibilityEvents, [false]);

    visibilityEvents.clear();

    final firstTap = await tester.startGesture(tapPoint);
    await firstTap.up();
    await tester.pump(const Duration(milliseconds: 100));
    final secondTap = await tester.startGesture(tapPoint);
    await secondTap.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(player.state.playing, isFalse);
    expect(pauseCount, 1);
    expect(visibilityEvents, isEmpty);
  });

  testWidgets(
      'double tap keeps visible mobile controls after resuming playback',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final player = _FakePlayerAdapter(playing: false);
    addTearDown(player.dispose);

    final visibilityEvents = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MobilePlayerControls(
            player: player,
            onControlsVisibilityChanged: visibilityEvents.add,
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

    await tester.pump();
    visibilityEvents.clear();

    const tapPoint = Offset(24, 300);
    final firstTap = await tester.startGesture(tapPoint);
    await firstTap.up();
    await tester.pump(const Duration(milliseconds: 100));
    final secondTap = await tester.startGesture(tapPoint);
    await secondTap.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(player.state.playing, isTrue);
    expect(visibilityEvents, isEmpty);
  });

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

  testWidgets('mobile progress bar uses slightly larger track and thumb',
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

    final activeTrack = find.byWidgetPredicate((widget) {
      if (widget is! Container) {
        return false;
      }
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.color == Colors.red &&
          decoration.shape != BoxShape.circle;
    });
    final thumb = find.byWidgetPredicate((widget) {
      if (widget is! Container) {
        return false;
      }
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          decoration.color == Colors.red;
    });

    expect(activeTrack, findsOneWidget);
    expect(thumb, findsOneWidget);
    expect(tester.getSize(activeTrack).height, 7);
    expect(tester.getSize(thumb), const Size(18, 18));
  });

  testWidgets('mobile preload progress keeps multiple cached segments',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final player = _FakePlayerAdapter(
      position: const Duration(minutes: 7),
      duration: const Duration(minutes: 10),
      cachedRanges: const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 2),
        ),
        PlayerCachedRange(
          start: Duration(minutes: 6),
          end: Duration(minutes: 8),
        ),
      ],
    );
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
            showPreloadProgress: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final preloadSegments = find.byWidgetPredicate((widget) {
      if (widget is! Container) {
        return false;
      }
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.shape != BoxShape.circle &&
          decoration.color == Colors.white.withValues(alpha: 0.34);
    });

    expect(preloadSegments, findsNWidgets(2));
  });

  testWidgets(
      'restarts hide countdown after switching to a new episode player while playing',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final firstPlayer = _FakePlayerAdapter()..emitPlaying(true);
    final secondPlayer = _FakePlayerAdapter()..emitPlaying(true);
    addTearDown(firstPlayer.dispose);
    addTearDown(secondPlayer.dispose);

    final playbackSpeed = ValueNotifier<double>(1.0);
    addTearDown(playbackSpeed.dispose);
    final visibilityEvents = <bool>[];

    Future<void> pumpControls(_FakePlayerAdapter player, int episodeIndex) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobilePlayerControls(
              player: player,
              onControlsVisibilityChanged: visibilityEvents.add,
              onFullscreenChange: (_) {},
              videoUrl: 'https://example.com/video-$episodeIndex.m3u8',
              currentEpisodeIndex: episodeIndex,
              playbackSpeedListenable: playbackSpeed,
              onSetSpeed: (_) async {},
              onEnterPipMode: () async {},
              isPipMode: false,
            ),
          ),
        ),
      );
    }

    await pumpControls(firstPlayer, 0);
    await tester.pump();

    await pumpControls(secondPlayer, 1);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(visibilityEvents, contains(false));
  });
}

class _FakePlayerAdapter implements PlayerAdapter {
  _FakePlayerAdapter({
    this.seekCompleter,
    this.emitSeekPositionToStream = true,
    Duration? position,
    Duration? duration,
    List<PlayerCachedRange>? cachedRanges,
    bool playing = true,
  })  : _stream = _FakePlayerStream(),
        _state = _FakePlayerState(
          playingValue: playing,
          positionValue: position ?? Duration.zero,
          durationValue: duration ?? const Duration(minutes: 12),
          cachedRangesValue: cachedRanges ?? const [],
        );

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

  void emitPlaying(bool playing) {
    _state.playingValue = playing;
    _stream.playingController.add(playing);
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
  final networkSpeedController = StreamController<int>.broadcast();

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
    await cachedRangesController.close();
    await completedController.close();
    await volumeController.close();
    await rateController.close();
    await bufferingController.close();
    await networkSpeedController.close();
  }
}

class _FakePlayerState implements PlayerAdapterState {
  _FakePlayerState({
    this.playingValue = true,
    this.positionValue = Duration.zero,
    this.durationValue = const Duration(minutes: 12),
    this.cachedRangesValue = const [],
  });

  bool playingValue;
  Duration positionValue;
  Duration durationValue;
  Duration bufferValue = Duration.zero;
  List<PlayerCachedRange> cachedRangesValue;
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
  int get networkSpeedBytesPerSecond => 0;

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
