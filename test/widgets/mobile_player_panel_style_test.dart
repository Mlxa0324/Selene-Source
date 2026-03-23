import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;

import 'package:selene/models/search_result.dart';
import 'package:selene/widgets/player_adapter.dart';
import 'package:selene/widgets/short_drama_controls.dart';

void main() {
  group('short drama dialog styling', () {
    testWidgets(
        'episodes sheet keeps player area visible with transparent barrier',
        (tester) async {
      await _pumpShortDramaControls(tester, theme: ThemeData.light());

      await tester.tap(find.textContaining('选集 ·'));
      await tester.pumpAndSettle();

      expect(
        _currentBarrierColor(tester),
        anyOf(isNull, equals(Colors.transparent)),
      );
    });

    testWidgets(
        'settings sheet keeps player visible while using an opaque dark background',
        (tester) async {
      await _pumpShortDramaControls(tester, theme: ThemeData.dark());

      await tester.longPressAt(const Offset(200, 200));
      await tester.pumpAndSettle();

      expect(
        _currentBarrierColor(tester),
        anyOf(isNull, equals(Colors.transparent)),
      );

      final decoration = _panelDecoration(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() == '_ShortDramaSettingsSheet',
        ),
      );

      expect(decoration.color, equals(Colors.black));
    });
  });
}

BoxDecoration _panelDecoration(WidgetTester tester, Finder panelFinder) {
  final containers = tester.widgetList<Container>(
    find.descendant(
      of: panelFinder,
      matching: find.byType(Container),
    ),
  );

  for (final container in containers) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration) {
      return decoration;
    }
  }

  throw StateError('No decorated container found for $panelFinder');
}

Color? _currentBarrierColor(WidgetTester tester) {
  final barriers = tester.widgetList<Widget>(
    find.byWidgetPredicate(
      (widget) => widget is ModalBarrier || widget is AnimatedModalBarrier,
    ),
  );

  for (final barrier in barriers.toList().reversed) {
    if (barrier is AnimatedModalBarrier) {
      return barrier.color.value;
    }
    if (barrier is ModalBarrier) {
      return barrier.color;
    }
  }

  throw StateError('No modal barrier found');
}

Future<void> _pumpShortDramaControls(
  WidgetTester tester, {
  required ThemeData theme,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(600, 1000));

  final player = _FakePlayerAdapter();

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SizedBox.expand(
          child: ShortDramaControls(
            player: player,
            onControlsVisibilityChanged: (_) {},
            onFullscreenChange: (_) {},
            videoUrl: 'https://example.com/video.m3u8',
            videoTitle: '测试短剧',
            currentEpisodeIndex: 0,
            totalEpisodes: 3,
            episodesTitles: const ['第1集', '第2集', '第3集'],
            currentSource: 'source-a',
            currentId: 'id-1',
            allSources: [
              SearchResult(
                id: 'id-1',
                title: '测试短剧',
                poster: '',
                episodes: const ['ep1', 'ep2', 'ep3'],
                episodesTitles: const ['第1集', '第2集', '第3集'],
                source: 'source-a',
                sourceName: '测试源',
                year: '2026',
              ),
            ],
            playbackSpeedListenable: ValueNotifier<double>(1.0),
            onSetSpeed: (_) async {},
            isFavorite: false,
            onFavoriteToggle: () {},
            onCastPressed: () {},
            videoCover: '',
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
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
