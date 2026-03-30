import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import 'package:selene/widgets/mobile_player_controls.dart';
import 'package:selene/widgets/player_adapter.dart';

void main() {
  testWidgets('notifies parent after dragging the mobile progress bar',
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

    expect(reportedSeekPosition, isNotNull);
    expect(reportedSeekPosition, equals(player.state.position));
    expect(reportedSeekPosition, greaterThan(const Duration(minutes: 1)));

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _FakePlayerAdapter implements PlayerAdapter {
  _FakePlayerAdapter()
      : _stream = _FakePlayerStream(),
        _state = _FakePlayerState();

  final _FakePlayerStream _stream;
  final _FakePlayerState _state;

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
  final completedController = StreamController<bool>.broadcast();
  final volumeController = StreamController<double>.broadcast();
  final rateController = StreamController<double>.broadcast();
  final bufferingController = StreamController<bool>.broadcast();

  @override
  Stream<Duration> get buffer => bufferController.stream;

  @override
  Stream<bool> get buffering => bufferingController.stream;

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
