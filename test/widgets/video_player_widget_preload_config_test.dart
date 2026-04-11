import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:selene/models/playback_preload.dart';
import 'package:selene/models/player_cached_range.dart';
import 'package:selene/widgets/player_adapter.dart';
import 'package:selene/widgets/video_player_widget.dart';

void main() {
  test('video player widget exposes unified playback preload level', () {
    const widget = VideoPlayerWidget(
      isShortDrama: false,
      playbackPreloadLevel: PlaybackPreloadLevel.medium,
    );

    expect(widget.playbackPreloadLevel, PlaybackPreloadLevel.medium);
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
