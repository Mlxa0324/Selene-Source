import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:selene/models/favorite_item.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/tv_app/screens/tv_video_detail_screen.dart';

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
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);
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
