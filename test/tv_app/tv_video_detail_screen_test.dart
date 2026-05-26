import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:selene/models/favorite_item.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/tv_app/screens/tv_video_detail_screen.dart';
import 'package:selene/widgets/player_settings_panel.dart';
import 'package:selene/widgets/video_player_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders TV detail layout sections in requested order',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult('source_a', '主源'),
            sources: [
              _searchResult('source_a', '主源'),
              _searchResult('source_b', '备用源'),
            ],
            recommends: [
              _videoInfo('recommend_1', '推荐影片'),
            ],
          ),
          playerBuilder: (_, __) => Container(
            key: const ValueKey('tv-detail-player-placeholder'),
            color: Colors.black,
          ),
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-detail-player-placeholder')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('tv-detail-player-entry')), findsOneWidget);
    expect(find.text('主影片'), findsWidgets);
    expect(find.text('全屏'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(
      Focus.of(tester
              .element(find.byKey(const ValueKey('tv-detail-player-entry'))))
          .hasFocus,
      isTrue,
    );
    final emptyHeartIcon = tester.widget<Icon>(find.byIcon(LucideIcons.heart));
    expect(emptyHeartIcon.color!.toARGB32(), 0xFFFFFFFF);
    expect(find.text('换源'), findsOneWidget);
    expect(find.text('选集'), findsOneWidget);
    expect(find.text('相关推荐'), findsOneWidget);
    expect(find.text('回到顶部'), findsOneWidget);
    expect(find.text('返回上一级'), findsNothing);
    expect(find.text('备用源'), findsOneWidget);
    expect(find.text('推荐影片'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-detail-source-list')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tv-detail-episode-list')), findsOneWidget);
  });

  testWidgets('moving focus from player to fullscreen keeps scroll position',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult('source_a', '主源'),
            sources: [
              _searchResult('source_a', '主源'),
            ],
            recommends: const [],
          ),
          playerBuilder: (_, __) => Container(
            key: const ValueKey('tv-detail-player-placeholder'),
            color: Colors.black,
          ),
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final scrollable = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final controller = scrollable.controller!;
    expect(controller.offset, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('全屏'), findsOneWidget);
    expect(controller.offset, 0);
  });

  testWidgets('renders episode groups for long TV episode lists',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '长剧集'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 25,
            ),
            sources: [
              _searchResult('source_a', '主源', episodeCount: 25),
            ],
            recommends: const [],
          ),
          playerBuilder: (_, __) => Container(
            key: const ValueKey('tv-detail-player-placeholder'),
            color: Colors.black,
          ),
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-detail-episode-group-list')),
        findsOneWidget);
    expect(find.text('1-20'), findsOneWidget);
    expect(find.text('21-25'), findsOneWidget);
    expect(find.text('第1集'), findsOneWidget);
    expect(find.text('第25集'), findsNothing);
  });

  testWidgets('switches visible episode range after selecting group label',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '长剧集'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 25,
            ),
            sources: [
              _searchResult('source_a', '主源', episodeCount: 25),
            ],
            recommends: const [],
          ),
          playerBuilder: (_, __) => Container(
            key: const ValueKey('tv-detail-player-placeholder'),
            color: Colors.black,
          ),
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('第21集'), findsNothing);
    expect(find.text('第25集'), findsNothing);

    await tester.tap(find.text('21-25'));
    await tester.pumpAndSettle();

    expect(find.text('第1集'), findsNothing);
    expect(find.text('第21集'), findsOneWidget);
    expect(find.text('第25集'), findsOneWidget);
  });

  testWidgets('opens TV fullscreen player from detail fullscreen action',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult('source_a', '主源'),
            sources: [
              _searchResult('source_a', '主源'),
            ],
            recommends: const [],
          ),
          playerBuilder: (_, __) => Container(
            key: const ValueKey('tv-detail-player-placeholder'),
            color: Colors.black,
          ),
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('全屏'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);
  });

  testWidgets('opens fullscreen player from current preview position',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setTvSurfaceSize(tester);
    Duration? fullscreenStartPosition;
    var fullscreenUpdateCount = 0;
    var detailControllerCreated = false;
    var fullscreenControllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult('source_a', '主源'),
            sources: [
              _searchResult('source_a', '主源'),
            ],
            recommends: const [],
          ),
          playerBuilder: (_, onControllerCreated) {
            if (!detailControllerCreated) {
              detailControllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(minutes: 9, seconds: 51),
                  duration: const Duration(minutes: 59, seconds: 11),
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: (_, onControllerCreated) {
            if (!fullscreenControllerCreated) {
              fullscreenControllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: Duration.zero,
                  duration: const Duration(minutes: 59, seconds: 11),
                  onUpdateDataSource: (_, {startAt, headers}) {
                    fullscreenUpdateCount += 1;
                    fullscreenStartPosition = startAt;
                  },
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('全屏'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 120));

    expect(
        find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);
    expect(fullscreenUpdateCount, greaterThan(0));
    expect(fullscreenStartPosition, const Duration(minutes: 9, seconds: 51));
  });

  testWidgets('renders first incremental source before all sources finish',
      (tester) async {
    await _setTvSurfaceSize(tester);
    final moreSourcesCompleter = Completer<List<SearchResult>>();

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片'),
          loadInitialSources: (_, __) async => const [],
          loadMoreSources: (_, __, onIncrementalResults) {
            onIncrementalResults([
              _searchResult('source_a', '主源'),
            ]);
            return moreSourcesCompleter.future;
          },
          loadRecommends: (_, __, ___) async => const [],
          playerBuilder: (_, __) => Container(
            key: const ValueKey('tv-detail-player-placeholder'),
            color: Colors.black,
          ),
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        find.byKey(const ValueKey('tv-detail-player-entry')), findsOneWidget);
    expect(find.text('主源'), findsOneWidget);
    expect(find.text('备用源'), findsNothing);

    moreSourcesCompleter.complete([
      _searchResult('source_a', '主源'),
      _searchResult('source_b', '备用源'),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('备用源'), findsOneWidget);
  });

  testWidgets('favorite action uses red heart icon when current video is saved',
      (tester) async {
    await _setTvSurfaceSize(tester);
    final cacheService = PageCacheService();
    cacheService.setCache<List<FavoriteItem>>(
      'favorites',
      [
        FavoriteItem(
          id: 'main',
          source: 'test',
          title: '主影片',
          sourceName: '测试源',
          year: '2026',
          cover: '',
          totalEpisodes: 2,
          saveTime: DateTime.now().millisecondsSinceEpoch,
          origin: '',
        ),
      ],
    );
    addTearDown(cacheService.clearAllCache);

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult('source_a', '主源'),
            sources: [
              _searchResult('source_a', '主源'),
            ],
            recommends: const [],
          ),
          playerBuilder: (_, __) => Container(
            key: const ValueKey('tv-detail-player-placeholder'),
            color: Colors.black,
          ),
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('已收藏'), findsOneWidget);
    final heartIcon = tester.widget<Icon>(find.byIcon(LucideIcons.heart));
    expect(heartIcon.color!.toARGB32(), 0xFFE50914);
  });

  testWidgets('escape pops TV detail page like remote back key',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TvVideoDetailScreen(
                        videoInfo: _videoInfo('main', '主影片'),
                        loadDetail: (_, __) async => TvVideoDetailData(
                          currentDetail: _searchResult('source_a', '主源'),
                          sources: [
                            _searchResult('source_a', '主源'),
                          ],
                          recommends: const [],
                        ),
                        playerBuilder: (_, __) => Container(
                          key: const ValueKey(
                            'tv-detail-player-placeholder',
                          ),
                          color: Colors.black,
                        ),
                        fullscreenPlayerBuilder: (_, __) => Container(
                          key: const ValueKey(
                            'tv-fullscreen-player-placeholder',
                          ),
                          color: Colors.black,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('打开详情页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开详情页'));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('tv-detail-player-entry')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('打开详情页'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-detail-player-entry')), findsNothing);
  });
}

Future<void> _setTvSurfaceSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _FakeVideoPlayerWidgetController implements VideoPlayerWidgetController {
  _FakeVideoPlayerWidgetController({
    required this.isPlaying,
    required this.currentPosition,
    required this.duration,
    this.onUpdateDataSource,
  });

  @override
  final bool isPlaying;

  @override
  final Duration? currentPosition;

  @override
  final Duration? duration;

  final FutureOr<void> Function(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  })? onUpdateDataSource;

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
  }) async {
    await onUpdateDataSource?.call(url, startAt: startAt, headers: headers);
  }

  @override
  Size? get videoSize => null;

  @override
  double? get volume => 1.0;
}

VideoInfo _videoInfo(String id, String title) {
  return VideoInfo(
    id: id,
    source: 'test',
    title: title,
    sourceName: '测试源',
    year: '2026',
    cover: '',
    index: 1,
    totalEpisodes: 2,
    playTime: 0,
    totalTime: 0,
    saveTime: 0,
    searchTitle: title,
  );
}

SearchResult _searchResult(
  String source,
  String sourceName, {
  int episodeCount = 2,
}) {
  final episodeIndexes = List<int>.generate(episodeCount, (index) => index + 1);
  return SearchResult(
    id: 'detail_$source',
    title: '主影片',
    poster: '',
    episodes: episodeIndexes
        .map((index) => 'https://example.com/$index.m3u8')
        .toList(),
    episodesTitles: episodeIndexes.map((index) => '第$index集').toList(),
    source: source,
    sourceName: sourceName,
    year: '2026',
    desc: '这是一段详情介绍。',
  );
}
