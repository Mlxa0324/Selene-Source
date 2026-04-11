import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import 'package:selene/models/player_cached_range.dart';
import 'package:selene/widgets/player_adapter.dart';
import 'package:selene/widgets/pc_player_controls.dart';

void main() {
  test('resolvePcCachedProgressSegment returns a full left segment when cached',
      () {
    final segment = resolvePcCachedProgressSegment(
      duration: const Duration(minutes: 20),
      position: const Duration(minutes: 5),
      cachedRanges: const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 12),
        ),
      ],
    );

    expect(segment, isNotNull);
    expect(segment!.start, 0);
    expect(segment.end, closeTo(0.6, 0.0001));
  });

  test('resolvePcCachedProgressSegment ignores invalid durations', () {
    final segment = resolvePcCachedProgressSegment(
      duration: Duration.zero,
      position: const Duration(minutes: 5),
      cachedRanges: const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 12),
        ),
      ],
    );

    expect(segment, isNull);
  });

  testWidgets('desktop progress bar uses slightly larger track and thumb',
      (tester) async {
    final player = _FakePlayerAdapter();
    addTearDown(player.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: CustomVideoProgressBar(
              player: player,
            ),
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

  testWidgets('desktop preload progress keeps multiple cached segments',
      (tester) async {
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
          body: SizedBox(
            width: 400,
            child: CustomVideoProgressBar(
              player: player,
              showPreloadProgress: true,
            ),
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
}

class _FakePlayerAdapter implements PlayerAdapter {
  _FakePlayerAdapter({
    Duration? position,
    Duration? duration,
    List<PlayerCachedRange>? cachedRanges,
  })
      : _stream = _FakePlayerStream(),
        _state = _FakePlayerState(
          positionValue: position ?? const Duration(minutes: 2),
          durationValue: duration ?? const Duration(minutes: 10),
          cachedRangesValue: cachedRanges ??
              const [
                PlayerCachedRange(
                  start: Duration.zero,
                  end: Duration(minutes: 3),
                ),
              ],
        );

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
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {
    _state.positionValue = position;
    _stream.positionController.add(position);
  }

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

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
  _FakePlayerState({
    required this.positionValue,
    required this.durationValue,
    required this.cachedRangesValue,
  });

  Duration positionValue;
  Duration durationValue;
  List<PlayerCachedRange> cachedRangesValue;

  @override
  Duration get buffer => const Duration(minutes: 3);

  @override
  bool get buffering => false;

  @override
  List<PlayerCachedRange> get cachedRanges => cachedRangesValue;

  @override
  Duration get duration => durationValue;

  @override
  double get height => 0;

  @override
  bool get playing => true;

  @override
  Duration get position => positionValue;

  @override
  double get rate => 1;

  @override
  double get volume => 100;

  @override
  double get width => 0;
}
