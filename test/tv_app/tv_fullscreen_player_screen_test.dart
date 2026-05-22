import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_fullscreen_player_screen.dart';

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
    expect(find.text('35:30 / 1:46:59'), findsOneWidget);
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
