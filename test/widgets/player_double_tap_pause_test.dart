import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import 'package:selene/models/player_cached_range.dart';
import 'package:selene/widgets/pc_player_controls.dart';
import 'package:selene/widgets/player_adapter.dart';
import 'package:selene/widgets/short_drama_controls.dart';

void main() {
  testWidgets('desktop blank area pauses only on double tap', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(900, 600));

    final player = _FakePlayerAdapter();
    addTearDown(player.dispose);
    final fullscreenChanges = <bool>[];
    var pauseCallbacks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: PCPlayerControls(
              player: player,
              videoUrl: 'https://example.com/video.m3u8',
              playbackSpeedListenable: ValueNotifier<double>(1.0),
              onSetSpeed: (_) async {},
              onPause: () => pauseCallbacks++,
              onFullscreenChange: fullscreenChanges.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final blankAreaGesture = _desktopBlankAreaGesture(tester);

    blankAreaGesture.onTap!();
    await tester.pump();

    expect(player.pauseCalls, 0);
    expect(player.playCalls, 0);
    expect(pauseCallbacks, 0);

    blankAreaGesture.onDoubleTap!();
    await tester.pump();

    expect(player.pauseCalls, 1);
    expect(player.state.playing, isFalse);
    expect(pauseCallbacks, 1);
    expect(fullscreenChanges, isEmpty);
  });

  testWidgets('short drama layer pauses only on double tap', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(420, 900));

    final player = _FakePlayerAdapter();
    addTearDown(player.dispose);
    final controlsVisibility = <bool>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: ShortDramaControls(
              player: player,
              onControlsVisibilityChanged: controlsVisibility.add,
              onFullscreenChange: (_) {},
              videoUrl: 'https://example.com/video.m3u8',
              playbackSpeedListenable: ValueNotifier<double>(1.0),
              onSetSpeed: (_) async {},
              videoCover: '',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gestureLayer = _shortDramaGestureLayer(tester);

    gestureLayer.onTap!();
    await tester.pump();

    expect(player.pauseCalls, 0);
    expect(player.playCalls, 0);

    expect(gestureLayer.onDoubleTap, isNotNull);
    gestureLayer.onDoubleTap!();
    await tester.pump();

    expect(player.pauseCalls, 1);
    expect(player.state.playing, isFalse);
  });
}

GestureDetector _desktopBlankAreaGesture(WidgetTester tester) {
  return tester.widget<GestureDetector>(
    find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.onHorizontalDragStart != null &&
          widget.onDoubleTap != null,
    ),
  );
}

GestureDetector _shortDramaGestureLayer(WidgetTester tester) {
  return tester.widget<GestureDetector>(
    find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.onLongPressStart != null &&
          widget.behavior == HitTestBehavior.opaque,
    ),
  );
}

class _FakePlayerAdapter implements PlayerAdapter {
  _FakePlayerAdapter()
      : _stream = _FakePlayerStream(),
        _state = _FakePlayerState();

  final _FakePlayerStream _stream;
  final _FakePlayerState _state;
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  PlayerAdapterStream get stream => _stream;

  @override
  _FakePlayerState get state => _state;

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
    pauseCalls++;
    _state.playingValue = false;
    _stream.playingController.add(false);
  }

  @override
  Future<void> play() async {
    playCalls++;
    _state.playingValue = true;
    _stream.playingController.add(true);
  }

  @override
  Future<void> seek(Duration position) async {
    _state.positionValue = position;
    _stream.positionController.add(position);
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
  Duration bufferValue = const Duration(minutes: 2);
  List<PlayerCachedRange> cachedRangesValue = const [];
  double volumeValue = 100;
  double rateValue = 1.0;

  @override
  Duration get buffer => bufferValue;

  @override
  bool get buffering => false;

  @override
  List<PlayerCachedRange> get cachedRanges => cachedRangesValue;

  @override
  Duration get duration => durationValue;

  @override
  double get height => 1080;

  @override
  bool get playing => playingValue;

  @override
  Duration get position => positionValue;

  @override
  double get rate => rateValue;

  @override
  double get volume => volumeValue;

  @override
  double get width => 1920;
}
