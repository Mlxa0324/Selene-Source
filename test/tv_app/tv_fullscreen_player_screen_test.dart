import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_fullscreen_player_screen.dart';
import 'package:selene/widgets/player_settings_panel.dart';
import 'package:selene/widgets/video_player_widget.dart';

void main() {
  testWidgets('opens TV player menu with down key and hides unsupported tabs',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
            _searchResult('source_b', '备用线路'),
          ],
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsOneWidget);
    expect(find.text('播放列表'), findsOneWidget);
    expect(find.text('播放线路'), findsOneWidget);
    expect(find.text('画面比例'), findsOneWidget);
    expect(find.text('倍速'), findsOneWidget);
    expect(find.text('其它'), findsOneWidget);
    expect(find.text('清晰度'), findsNothing);
    expect(find.text('内核'), findsNothing);
  });

  testWidgets('switches secondary menu when first level tab gets focus',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
            _searchResult('source_b', '备用线路'),
          ],
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.text('第1集'), findsOneWidget);
    expect(find.text('备用线路'), findsNothing);

    _focusNodeForMenuLabel(tester, '播放线路').requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('备用线路'), findsOneWidget);
  });

  testWidgets('uses smaller white text in TV player bottom menu',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('播放列表'));
    expect(text.style?.fontSize, 18);
    expect(text.style?.color, Colors.white);
  });

  testWidgets('uses mobile player display mode labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _focusNodeForMenuLabel(tester, '画面比例').requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('适应'), findsOneWidget);
    expect(find.text('填充'), findsOneWidget);
    expect(find.text('宽度'), findsOneWidget);
    expect(find.text('高度'), findsOneWidget);
    expect(find.text('默认'), findsNothing);
    expect(find.text('拉伸'), findsNothing);
  });

  testWidgets('back key closes TV player menu before popping fullscreen route',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TvFullscreenPlayerScreen(
                        videoInfo: _videoInfo(),
                        currentDetail: _searchResult('source_a', '主线路'),
                        sources: [
                          _searchResult('source_a', '主线路'),
                        ],
                        playerBuilder: (_, __) => const ColoredBox(
                          key: ValueKey('tv-fullscreen-player-placeholder'),
                          color: Colors.black,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('详情页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('详情页'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsNothing);
    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('详情页'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsNothing);
  });

  testWidgets('select toggles play pause when TV player menu is hidden',
      (tester) async {
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(minutes: 35, seconds: 25),
      duration: const Duration(hours: 1, minutes: 46, seconds: 59),
      playing: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          playbackController: playback,
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(playback.pauseCount, 1);
    expect(playback.playCount, 0);
    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsNothing);

    playback.playing = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(playback.playCount, 1);
  });

  testWidgets('space toggles play pause when TV player menu is hidden',
      (tester) async {
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(minutes: 35, seconds: 25),
      duration: const Duration(hours: 1, minutes: 46, seconds: 59),
      playing: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          playbackController: playback,
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(playback.pauseCount, 1);
    expect(playback.playCount, 0);
  });

  testWidgets('shows paused overlay matching TV playback shell',
      (tester) async {
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(seconds: 17),
      duration: const Duration(minutes: 45, seconds: 28),
      playing: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          playbackController: playback,
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-center-play')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('tv-fullscreen-bottom-progress')),
        findsOneWidget);
    expect(find.text('00:17'), findsOneWidget);
    expect(find.text('45:28'), findsOneWidget);
    expect(find.textContaining('按【菜单键】或【下键】'), findsOneWidget);
    expect(find.textContaining('提醒：'), findsNothing);
  });

  testWidgets('places fullscreen top decorations on both top sides',
      (tester) async {
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(seconds: 17),
      duration: const Duration(minutes: 45, seconds: 28),
      playing: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          playbackController: playback,
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final decorationFinder =
        find.byKey(const ValueKey('tv-fullscreen-top-decorations'));
    final leftFinder = find.byKey(const ValueKey('tv-fullscreen-top-left'));
    final rightFinder = find.byKey(const ValueKey('tv-fullscreen-top-right'));
    final decorationTop = tester.getTopLeft(decorationFinder);
    final leftTop = tester.getTopLeft(leftFinder);
    final rightTop = tester.getTopLeft(rightFinder);

    expect(decorationFinder, findsOneWidget);
    expect(leftFinder, findsOneWidget);
    expect(rightFinder, findsOneWidget);
    expect(decorationTop.dy, lessThan(30));
    expect(leftTop.dy, rightTop.dy);
    expect(leftTop.dy, lessThan(30));
    expect(rightTop.dx, greaterThan(leftTop.dx + 300));
  });

  testWidgets(
      'does not call setState during build when player controller is created',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          playerBuilder: (_, onControllerCreated) {
            return _SynchronousControllerCreatedProbe(
              onControllerCreated: onControllerCreated,
            );
          },
        ),
      ),
    );

    await tester.pump();
    final exception = tester.takeException();
    expect(exception, isNull);
    await tester.pump();
    expect(find.byKey(const ValueKey('tv-fullscreen-center-play')),
        findsOneWidget);
  });

  testWidgets('arrow key seek shows center time overlay when menu is hidden',
      (tester) async {
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(minutes: 35, seconds: 25),
      duration: const Duration(hours: 1, minutes: 46, seconds: 59),
      playing: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          playbackController: playback,
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(playback.seekPositions, [const Duration(minutes: 35, seconds: 30)]);
    expect(find.byKey(const ValueKey('tv-fullscreen-seek-overlay')),
        findsOneWidget);
    expect(find.text('35:30/1:46:59'), findsOneWidget);
    expect(find.textContaining('按【菜单键】或【下键】'), findsNothing);
  });

  test('TV fullscreen seek acceleration eases from 5s to 29s', () {
    expect(TvFullscreenSeekStep.secondsForElapsed(Duration.zero), 5);
    expect(
      TvFullscreenSeekStep.secondsForElapsed(const Duration(seconds: 3)),
      29,
    );
  });
}

FocusNode _focusNodeForMenuLabel(WidgetTester tester, String label) {
  final focusFinder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) => widget is Focus && widget.focusNode != null,
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

VideoInfo _videoInfo() {
  return VideoInfo(
    id: 'main',
    source: 'source_a',
    title: '主角',
    sourceName: '主线路',
    year: '2026',
    cover: '',
    index: 1,
    totalEpisodes: 2,
    playTime: 0,
    totalTime: 0,
    saveTime: 0,
    searchTitle: '主角',
  );
}

SearchResult _searchResult(String source, String sourceName) {
  return SearchResult(
    id: 'detail_$source',
    title: '主角',
    poster: '',
    episodes: const [
      'https://example.com/1.m3u8',
      'https://example.com/2.m3u8',
    ],
    episodesTitles: const ['第1集', '第2集'],
    source: source,
    sourceName: sourceName,
    year: '2026',
    desc: '这是一段详情介绍。',
  );
}

class _FakeTvFullscreenPlaybackController
    implements TvFullscreenPlaybackController {
  _FakeTvFullscreenPlaybackController({
    required this.position,
    required this.duration,
    required this.playing,
  });

  Duration position;
  Duration duration;
  bool playing;
  int playCount = 0;
  int pauseCount = 0;
  final List<Duration> seekPositions = [];

  @override
  Duration? get currentPosition => position;

  @override
  Duration? get totalDuration => duration;

  @override
  bool get isPlaying => playing;

  @override
  Future<void> pause() async {
    pauseCount++;
    playing = false;
  }

  @override
  Future<void> play() async {
    playCount++;
    playing = true;
  }

  @override
  Future<void> seekTo(Duration position) async {
    this.position = position;
    seekPositions.add(position);
  }
}

class _FakeVideoPlayerWidgetController implements VideoPlayerWidgetController {
  _FakeVideoPlayerWidgetController({
    required this.isPlaying,
    required this.currentPosition,
    required this.duration,
  });

  @override
  final bool isPlaying;

  @override
  final Duration? currentPosition;

  @override
  final Duration? duration;

  @override
  void addProgressListener(VoidCallback listener) {}

  @override
  Future<void> dispose() async {}

  @override
  void exitWebFullscreen() {}

  @override
  bool get isPipMode => false;

  @override
  double get playbackSpeed => 1.0;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  void removeProgressListener(VoidCallback listener) {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  void setVideoFit(VideoFitType fitType) {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> updateDataSource(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  }) async {}

  @override
  Size? get videoSize => null;

  @override
  double? get volume => 1.0;
}

class _SynchronousControllerCreatedProbe extends StatefulWidget {
  const _SynchronousControllerCreatedProbe({
    required this.onControllerCreated,
  });

  final void Function(VideoPlayerWidgetController controller)
      onControllerCreated;

  @override
  State<_SynchronousControllerCreatedProbe> createState() =>
      _SynchronousControllerCreatedProbeState();
}

class _SynchronousControllerCreatedProbeState
    extends State<_SynchronousControllerCreatedProbe> {
  @override
  void initState() {
    super.initState();
    widget.onControllerCreated(
      _FakeVideoPlayerWidgetController(
        isPlaying: false,
        currentPosition: const Duration(seconds: 3),
        duration: const Duration(minutes: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: ValueKey('tv-fullscreen-player-placeholder'),
      color: Colors.black,
    );
  }
}
