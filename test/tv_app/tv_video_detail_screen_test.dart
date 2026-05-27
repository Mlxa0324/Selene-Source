import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:selene/models/favorite_item.dart';
import 'package:selene/models/play_record.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/local_mode_storage_service.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/screens/tv_video_detail_screen.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';
import 'package:selene/widgets/player_settings_panel.dart';
import 'package:selene/widgets/video_player_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const ValueKey('tv-detail-player-placeholder')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('tv-detail-player-entry')), findsOneWidget);
    expect(find.text('主影片'), findsWidgets);
    expect(find.text('全屏'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-detail-clock')), findsOneWidget);
    final clockText = tester.widget<Text>(
      find.byKey(const ValueKey('tv-detail-clock')),
    );
    expect(clockText.data, matches(RegExp(r'^\d{2}:\d{2}$')));
    expect(
      Focus.of(tester
              .element(find.byKey(const ValueKey('tv-detail-player-entry'))))
          .hasFocus,
      isTrue,
    );
    final emptyHeartIcon = tester.widget<Icon>(find.byIcon(LucideIcons.heart));
    expect(emptyHeartIcon.color!.toARGB32(), 0xFFFFFFFF);
    expect(find.text('IvyTV'), findsOneWidget);
    expect(find.text('按返回键返回上一页 | 全屏时向下键可进行播放设置（倍数，其它）'), findsOneWidget);
    expect(find.text('切换线路'), findsOneWidget);
    expect(find.text('遇播放卡顿，音画不同步或无法播放时，请切换播放线路'), findsOneWidget);
    expect(find.textContaining('内核'), findsNothing);
    expect(find.text('换源'), findsNothing);
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

  testWidgets('detail source list shows episode counts sorted descending',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '多源影片'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '暴风资源',
              episodeCount: 45,
            ),
            sources: [
              _searchResult('source_a', '暴风资源', episodeCount: 45),
              _searchResult('source_b', '最大资源', episodeCount: 99),
              _searchResult('source_c', '短资源', episodeCount: 12),
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

    expect(find.text('最大资源'), findsOneWidget);
    expect(find.text('（99）'), findsOneWidget);
    expect(find.text('暴风资源'), findsOneWidget);
    expect(find.text('（45）'), findsOneWidget);

    final maxLeft = tester.getTopLeft(find.text('最大资源')).dx;
    final stormLeft = tester.getTopLeft(find.text('暴风资源')).dx;
    final shortLeft = tester.getTopLeft(find.text('短资源')).dx;
    expect(maxLeft, lessThan(stormLeft));
    expect(stormLeft, lessThan(shortLeft));
  });

  testWidgets('detail episode card height stays at least source card height',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 3,
            ),
            sources: [
              _searchResult('source_a', '主源', episodeCount: 3),
              _searchResult('source_b', '备用源', episodeCount: 3),
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

    final sourceButtonFinder = find
        .ancestor(
          of: find.text('主源'),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final sourceButton = tester.widget<AnimatedContainer>(sourceButtonFinder);

    final episodeButtonFinder = find
        .ancestor(
          of: find.text('第1集'),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final episodeButton = tester.widget<AnimatedContainer>(episodeButtonFinder);
    final sourceButtonRect = tester.getRect(sourceButtonFinder);
    final episodeButtonRect = tester.getRect(episodeButtonFinder);

    expect(
      episodeButtonRect.height,
      greaterThanOrEqualTo(sourceButtonRect.height),
    );
    expect(sourceButton.constraints!.minHeight, greaterThan(0));
    expect(episodeButton.constraints!.minHeight, greaterThan(0));
  });

  testWidgets('detail header search action uses configured button radius',
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

    final searchButton = find.descendant(
      of: find.byKey(const ValueKey('tv-detail-search-action')),
      matching: find.byType(AnimatedContainer),
    );
    final container = tester.widget<AnimatedContainer>(searchButton);
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.borderRadius, BorderRadius.circular(22));
  });

  testWidgets('opens TV search screen from detail header search action',
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

    await _pumpUntilFound(tester, find.text('搜索'));
    await tester.tap(find.text('搜索'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const ValueKey('tv-search-screen')), findsOneWidget);
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

  testWidgets('detail page guide stays pinned while content scrolls',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longDesc = List<String>.filled(
      18,
      '这是一段很长的详情介绍，用来拉高详情内容，确保页面滚动时顶部引导栏保持固定。',
    ).join();

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '长剧集'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 40,
              desc: longDesc,
            ),
            sources: [
              _searchResult(
                'source_a',
                '主源',
                episodeCount: 40,
                desc: longDesc,
              ),
            ],
            recommends: List<VideoInfo>.generate(
              8,
              (index) => _videoInfo('recommend_$index', '推荐影片$index'),
            ),
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
    final guideTitleBefore = tester.getTopLeft(find.text('IvyTV')).dy;
    final guideActionBefore = tester
        .getTopLeft(find.byKey(const ValueKey('tv-detail-search-action')))
        .dy;

    final controller = _detailScrollController(tester);
    controller.jumpTo(220);
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
    expect(tester.getTopLeft(find.text('IvyTV')).dy, guideTitleBefore);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('tv-detail-search-action')))
          .dy,
      guideActionBefore,
    );
  });

  testWidgets('detail page guide shares the same leading line as content',
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

    final guideLeft = tester.getTopLeft(find.text('IvyTV')).dx;
    final sourceTitleLeft = tester.getTopLeft(find.text('切换线路')).dx;
    final recommendTitleLeft = tester.getTopLeft(find.text('相关推荐')).dx;

    expect((guideLeft - sourceTitleLeft).abs(), lessThanOrEqualTo(1));
    expect((guideLeft - recommendTitleLeft).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('paused detail preview shows TV playback chrome', (tester) async {
    await _setTvSurfaceSize(tester);
    var controllerCreated = false;

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
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: false,
                  currentPosition: const Duration(minutes: 2, seconds: 49),
                  duration: const Duration(minutes: 24, seconds: 21),
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(_FakeVideoPlayerWidgetController.loadingHoldDuration);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('tv-detail-preview-center-play')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tv-detail-preview-bottom-progress')),
      findsOneWidget,
    );
    expect(find.text('02:49'), findsOneWidget);
    expect(find.text('24:21'), findsOneWidget);
  });

  testWidgets('loading detail preview shows spinner without pause chrome',
      (tester) async {
    await _setTvSurfaceSize(tester);
    var controllerCreated = false;

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
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: false,
                  isLoading: true,
                  currentPosition: const Duration(minutes: 2, seconds: 49),
                  duration: const Duration(minutes: 24, seconds: 21),
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const ValueKey('tv-detail-preview-loading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tv-detail-preview-center-play')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('tv-detail-preview-bottom-progress')),
      findsNothing,
    );
  });

  testWidgets('detail preview spinner hides once playback has started',
      (tester) async {
    await _setTvSurfaceSize(tester);
    var controllerCreated = false;

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
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  isLoading: true,
                  currentPosition: const Duration(minutes: 2, seconds: 49),
                  duration: const Duration(minutes: 24, seconds: 21),
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const ValueKey('tv-detail-preview-loading')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('tv-detail-preview-center-play')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('tv-detail-preview-bottom-progress')),
      findsNothing,
    );
  });

  testWidgets('source row up key focuses nearest hero control', (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult('source_a', '左侧主源'),
            sources: [
              _searchResult('source_a', '左侧主源'),
              _searchResult('source_b', '资源二很长'),
              _searchResult('source_c', '资源三很长'),
              _searchResult('source_d', '资源四很长'),
              _searchResult('source_e', '资源五很长'),
              _searchResult('source_f', '资源六很长'),
              _searchResult('source_g', '资源七很长'),
              _searchResult('source_h', '右侧资源八很长'),
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

    Focus.of(tester.element(find.text('全屏'))).requestFocus();
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text('左侧主源'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(
      Focus.of(tester
              .element(find.byKey(const ValueKey('tv-detail-player-entry'))))
          .hasFocus,
      isTrue,
    );

    Focus.of(tester.element(find.text('右侧资源八很长'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(Focus.of(tester.element(find.text('收藏'))).hasFocus, isTrue);
  });

  testWidgets('source row up key scrolls to top when focusing player',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult('source_a', '左侧主源'),
            sources: [
              _searchResult('source_a', '左侧主源'),
              _searchResult('source_b', '备用源'),
            ],
            recommends: List<VideoInfo>.generate(
              6,
              (index) => _videoInfo('recommend_$index', '推荐$index'),
            ),
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
    final controller = _detailScrollController(tester);
    controller.jumpTo(360);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));

    Focus.of(tester.element(find.text('左侧主源'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(
      Focus.of(tester
              .element(find.byKey(const ValueKey('tv-detail-player-entry'))))
          .hasFocus,
      isTrue,
    );
    expect(controller.offset, 0);
  });

  testWidgets('hero boundary keys keep focus in place except search left',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult('source_a', '主源'),
            sources: const [],
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

    await _expectFocusStaysAfterKey(
      tester,
      focusFinder: find.byKey(const ValueKey('tv-detail-player-entry')),
      key: LogicalKeyboardKey.arrowLeft,
    );
    final searchTextFinder = find.text('搜索');
    Focus.of(tester.element(searchTextFinder)).requestFocus();
    await tester.pumpAndSettle();
    _expectFocusedWithin(tester, searchTextFinder);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    _expectFocusedWithin(
      tester,
      find.byKey(const ValueKey('tv-detail-player-entry')),
    );
    await _expectFocusStaysAfterKey(
      tester,
      focusFinder: searchTextFinder,
      key: LogicalKeyboardKey.arrowRight,
    );
    await _expectFocusStaysAfterKey(
      tester,
      focusFinder: searchTextFinder,
      key: LogicalKeyboardKey.arrowUp,
    );
    await _expectFocusStaysAfterKey(
      tester,
      focusFinder: find.text('收藏'),
      key: LogicalKeyboardKey.arrowRight,
    );
  });

  testWidgets('action buttons down key focuses selected source row',
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
              _searchResult('source_b', '备用源二'),
              _searchResult('source_c', '备用源三'),
              _searchResult('source_d', '备用源四'),
              _searchResult('source_e', '备用源五'),
              _searchResult('source_f', '备用源六'),
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

    Focus.of(tester.element(find.text('全屏'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('主源'));

    Focus.of(tester.element(find.text('已收藏'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('主源'));
  });

  testWidgets('action buttons up key focuses detail search action',
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

    Focus.of(tester.element(find.text('全屏'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('搜索'));

    Focus.of(tester.element(find.text('已收藏'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('搜索'));
  });

  testWidgets('detail search down key focuses fullscreen action',
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

    Focus.of(tester.element(find.text('搜索'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _expectFocused(tester, find.text('全屏'));
  });

  testWidgets('player down key restores current source focus', (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult('source_c', '线路三'),
            sources: [
              _searchResult('source_a', '线路一'),
              _searchResult('source_b', '线路二'),
              _searchResult('source_c', '线路三'),
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
    final controller = _detailScrollController(tester);
    expect(controller.offset, 0);

    Focus.of(tester
            .element(find.byKey(const ValueKey('tv-detail-player-entry'))))
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _expectFocused(tester, find.text('线路三'));
    final sourceOffset = controller.offset;
    expect(sourceOffset, greaterThanOrEqualTo(0));
    expect(sourceOffset, lessThan(240));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _expectFocused(tester, find.text('第1集'));
    final episodeOffset = controller.offset;
    expect(episodeOffset, greaterThanOrEqualTo(sourceOffset));
    expect(episodeOffset - sourceOffset, lessThan(220));
  });

  testWidgets('vertical arrows move through TV detail rows smoothly',
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
              _searchResult('source_b', '备用源', episodeCount: 25),
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

    Focus.of(tester.element(find.text('主源'))).requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('第1集'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('1-20'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('推荐影片'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('1-20'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('第1集'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('主源'));
  });

  testWidgets('source down key enters first episode in current group',
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
              episodeCount: 45,
            ),
            sources: [
              _searchResult('source_a', '主源', episodeCount: 45),
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
    await tester.tap(find.text('21-40'));
    await tester.pumpAndSettle();

    Focus.of(tester.element(find.text('主源'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _expectFocused(tester, find.text('第21集'));
  });

  testWidgets('source row down key enters episodes and recommendations',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '短剧集'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult('source_c', '右侧资源三'),
            sources: [
              _searchResult('source_a', '左侧资源一'),
              _searchResult('source_b', '中间资源二'),
              _searchResult('source_c', '右侧资源三'),
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

    Focus.of(tester.element(find.text('右侧资源三'))).requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('第1集'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('推荐影片'));
  });

  testWidgets('detail row transitions restore focused source episode and group',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo(
            'main',
            '长剧集',
            source: 'source_a',
            index: 208,
            totalEpisodes: 500,
          ),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '线路一',
              episodeCount: 500,
            ),
            sources: [
              _searchResult('source_z', '超长线路资源零', episodeCount: 500),
              _searchResult('source_y', '超长线路资源一', episodeCount: 500),
              _searchResult('source_x', '超长线路资源二', episodeCount: 500),
              _searchResult('source_w', '超长线路资源三', episodeCount: 500),
              _searchResult('source_v', '超长线路资源四', episodeCount: 500),
              _searchResult('source_a', '线路一', episodeCount: 500),
              _searchResult('source_b', '线路二', episodeCount: 500),
              _searchResult('source_c', '线路三', episodeCount: 500),
              _searchResult('source_d', '线路四', episodeCount: 500),
              _searchResult('source_e', '线路五', episodeCount: 500),
            ],
            recommends: [
              _videoInfo('recommend_1', '推荐影片一'),
              _videoInfo('recommend_2', '推荐影片二'),
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

    Focus.of(tester.element(find.text('线路三'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 420));
    _expectFocused(tester, find.text('第208集'));
    _expectFinderNearListLeadingEdge(
      tester,
      listKey: 'tv-detail-episode-list',
      itemFinder: find.text('第208集'),
      maxLeadingGap: 64,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 420));
    _expectFocused(tester, find.text('线路三'));
    _expectFinderVisibleWithinList(
      tester,
      listKey: 'tv-detail-source-list',
      itemFinder: find.text('线路三'),
    );

    Focus.of(tester.element(find.text('第213集'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('线路三'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('第213集'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 420));
    _expectFocused(tester, find.text('201-220'));
    _expectFinderNearListLeadingEdge(
      tester,
      listKey: 'tv-detail-episode-group-list',
      itemFinder: find.text('201-220'),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('第213集'));

    Focus.of(tester.element(find.text('推荐影片二'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('201-220'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('推荐影片二'));
  });

  testWidgets('recommend down key focuses bottom action and scrolls page',
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
    final scrollable = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    final controller = scrollable.controller!;

    Focus.of(tester.element(find.text('推荐影片'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _expectFocused(tester, find.text('回到顶部'));
    expect(controller.offset, greaterThan(0));
  });

  testWidgets('recommend boundary keys keep focus and show edge shake',
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
            recommends: [
              _videoInfo('recommend_1', '推荐影片一'),
              _videoInfo('recommend_2', '推荐影片二'),
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

    expect(
      find.byKey(const ValueKey('tv-detail-recommend-list')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tv-edge-shake')), findsWidgets);

    await _expectFocusStaysAfterKey(
      tester,
      focusFinder: find.text('推荐影片一'),
      key: LogicalKeyboardKey.arrowLeft,
    );

    await _expectFocusStaysAfterKey(
      tester,
      focusFinder: find.text('推荐影片二'),
      key: LogicalKeyboardKey.arrowRight,
    );
  });

  testWidgets('bottom action returns focus to player after scrolling to top',
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
    final controller = _detailScrollController(tester);

    Focus.of(tester.element(find.text('推荐影片'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _expectFocused(tester, find.text('回到顶部'));
    expect(controller.offset, greaterThan(0));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
    expect(
      Focus.of(tester
              .element(find.byKey(const ValueKey('tv-detail-player-entry'))))
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('bottom action uses up for focus only and confirm for scroll',
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
    final controller = _detailScrollController(tester);

    Focus.of(tester.element(find.text('推荐影片'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _expectFocused(tester, find.text('回到顶部'));
    expect(controller.offset, greaterThan(0));

    await _expectFocusStaysAfterKey(
      tester,
      focusFinder: find.text('回到顶部'),
      key: LogicalKeyboardKey.arrowLeft,
    );
    await _expectFocusStaysAfterKey(
      tester,
      focusFinder: find.text('回到顶部'),
      key: LogicalKeyboardKey.arrowRight,
    );
    await _expectFocusStaysAfterKey(
      tester,
      focusFinder: find.text('回到顶部'),
      key: LogicalKeyboardKey.arrowDown,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    _expectFocused(tester, find.text('推荐影片'));
    expect(controller.offset, greaterThan(0));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _expectFocused(tester, find.text('回到顶部'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
    expect(
      Focus.of(tester
              .element(find.byKey(const ValueKey('tv-detail-player-entry'))))
          .hasFocus,
      isTrue,
    );
  });

  testWidgets('renders episode groups for long TV episode lists',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          key: const ValueKey('long-detail'),
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

  testWidgets('episode group label underlines when focused', (tester) async {
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

    Focus.of(tester.element(find.text('21-25'))).requestFocus();
    await tester.pumpAndSettle();

    final groupText = tester.widget<Text>(find.text('21-25'));
    expect(groupText.style?.decoration, TextDecoration.underline);
  });

  testWidgets('episode chips grow taller for long titles instead of ellipsis',
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
              episodeCount: 3,
              episodeTitles: const [
                '20260328乘风来袭特别加更完整版标题真的很长',
                '20260401加更版',
                '20260402先导片',
              ],
            ),
            sources: [
              _searchResult(
                'source_a',
                '主源',
                episodeCount: 3,
                episodeTitles: const [
                  '20260328乘风来袭特别加更完整版标题真的很长',
                  '20260401加更版',
                  '20260402先导片',
                ],
              ),
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

    final episodeListSize = tester.getSize(
      find.byKey(const ValueKey('tv-detail-episode-list')),
    );
    expect(episodeListSize.height, greaterThan(42));
  });

  testWidgets(
      'episode group labels stay below episodes and hide for short list',
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

    final episodeListBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('tv-detail-episode-list')))
        .dy;
    final groupListTop = tester
        .getTopLeft(find.byKey(const ValueKey('tv-detail-episode-group-list')))
        .dy;
    expect(groupListTop, greaterThan(episodeListBottom));

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          key: const ValueKey('short-detail'),
          videoInfo: _videoInfo('main', '短剧集'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 20,
            ),
            sources: [
              _searchResult('source_a', '主源', episodeCount: 20),
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
        findsNothing);
    expect(find.text('1-20'), findsNothing);
  });

  testWidgets('detail horizontal lists shake at right edge and keep focus',
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
              _searchResult('source_b', '备用源', episodeCount: 25),
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
    expect(find.byKey(const ValueKey('tv-edge-shake')), findsWidgets);

    Focus.of(tester.element(find.text('备用源'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 80));
    expect(Focus.of(tester.element(find.text('备用源'))).hasFocus, isTrue);

    Focus.of(tester.element(find.text('主源'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 80));
    expect(Focus.of(tester.element(find.text('主源'))).hasFocus, isTrue);

    await tester.tap(find.text('21-25'));
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text('第25集'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 80));
    expect(Focus.of(tester.element(find.text('第25集'))).hasFocus, isTrue);

    Focus.of(tester.element(find.text('21-25'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 80));
    expect(Focus.of(tester.element(find.text('21-25'))).hasFocus, isTrue);

    Focus.of(tester.element(find.text('1-20'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 80));
    expect(Focus.of(tester.element(find.text('1-20'))).hasFocus, isTrue);
  });

  testWidgets('detail option rows scroll independently while page stays stable',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '长剧集'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_1',
              '线路01超长名称用于固定宽度',
              episodeCount: 500,
            ),
            sources: List<SearchResult>.generate(
              12,
              (index) => _searchResult(
                'source_${index + 1}',
                '线路${(index + 1).toString().padLeft(2, '0')}超长名称用于固定宽度',
                episodeCount: 500,
              ),
            ),
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

    final pageController = _detailScrollController(tester);
    expect(pageController.offset, 0);

    final sourceOffsetBefore = _detailHorizontalOffset(
      tester,
      'tv-detail-source-list',
    );
    Focus.of(tester.element(find.text('线路05超长名称用于固定宽度'))).requestFocus();
    await tester.pumpAndSettle();
    final sourceOffsetAfter = _detailHorizontalOffset(
      tester,
      'tv-detail-source-list',
    );
    expect(sourceOffsetAfter, greaterThanOrEqualTo(sourceOffsetBefore));

    expect(pageController.offset, 0);
    await _expectDetailListStartsScrollingAfterHalf(
      tester,
      listKey: 'tv-detail-episode-list',
      beforeHalfFinder: find.text('第5集'),
      afterHalfFinder: find.text('第6集'),
    );
    await _expectDetailListStartsScrollingAfterHalf(
      tester,
      listKey: 'tv-detail-episode-group-list',
      beforeHalfFinder: find.text('121-140'),
      afterHalfFinder: find.text('181-200'),
    );
  });

  testWidgets('switches visible episode range when group label gets focus',
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

    Focus.of(tester.element(find.text('21-25'))).requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('第1集'), findsNothing);
    expect(find.text('第21集'), findsOneWidget);
    expect(find.text('第25集'), findsOneWidget);
  });

  testWidgets('episode group up key focuses nearest episode range',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo(
            'main',
            '长剧集',
            index: 208,
            totalEpisodes: 500,
          ),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 500,
            ),
            sources: [
              _searchResult('source_a', '主源', episodeCount: 500),
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

    await tester.tap(find.text('221-240'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 420));

    _expectFinderNearListLeadingEdge(
      tester,
      listKey: 'tv-detail-episode-group-list',
      itemFinder: find.text('221-240'),
    );

    Focus.of(tester.element(find.text('221-240'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 420));

    _expectFocused(tester, find.text('第221集'));
    _expectFinderNearListLeadingEdge(
      tester,
      listKey: 'tv-detail-episode-list',
      itemFinder: find.text('第221集'),
      maxLeadingGap: 74,
    );
  });

  testWidgets('detail preview auto plays next episode after completion',
      (tester) async {
    await _setTvSurfaceSize(tester);
    final updatedUrls = <String>[];
    final testHooks = TvVideoDetailScreenTestHooks();
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片', totalEpisodes: 3),
          testHooks: testHooks,
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 3,
            ),
            sources: [
              _searchResult('source_a', '主源', episodeCount: 3),
            ],
            recommends: const [],
          ),
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(seconds: 88),
                  duration: const Duration(seconds: 1000),
                  onUpdateDataSource: (url, {startAt, headers}) async {
                    updatedUrls.add(url);
                  },
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    updatedUrls.clear();

    testHooks.onVideoCompleted?.call();
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();

    expect(updatedUrls, ['https://example.com/2.m3u8']);
  });

  testWidgets(
      'detail page starts vertical scroll only after episode chips focus',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final longDesc = List<String>.filled(
      18,
      '这是一段很长的详情介绍，用来稳定撑高详情区，确保选集焦点进入时需要触发页面纵向滚动。',
    ).join();
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '长剧集'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 40,
              desc: longDesc,
            ),
            sources: [
              _searchResult(
                'source_a',
                '主源',
                episodeCount: 40,
                desc: longDesc,
              ),
              _searchResult(
                'source_b',
                '备用一',
                episodeCount: 40,
                desc: longDesc,
              ),
              _searchResult(
                'source_c',
                '备用二',
                episodeCount: 40,
                desc: longDesc,
              ),
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

    final controller = _detailScrollController(tester);
    expect(controller.offset, 0);

    Focus.of(
      tester.element(find.byKey(const ValueKey('tv-detail-player-entry'))),
    ).requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThanOrEqualTo(0));
    expect(controller.offset, lessThan(220));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(controller.offset, lessThan(360));
  });

  testWidgets('selected source and episode are visible on detail initial load',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo(
            'main',
            '长剧集',
            source: 'source_c',
            index: 220,
            totalEpisodes: 500,
            playTime: 120,
          ),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_c',
              '暴风资源',
              episodeCount: 500,
            ),
            sources: [
              _searchResult('source_a', '最大资源', episodeCount: 500),
              _searchResult('source_b', '电影天堂', episodeCount: 500),
              _searchResult('source_c', '暴风资源', episodeCount: 500),
              _searchResult('source_d', '极速资源', episodeCount: 500),
              _searchResult('source_e', '红牛资源', episodeCount: 500),
              _searchResult('source_f', '豪华资源', episodeCount: 500),
              _searchResult('source_g', '飘花资源', episodeCount: 500),
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

    _expectFinderVisibleWithinList(
      tester,
      listKey: 'tv-detail-source-list',
      itemFinder: find.text('暴风资源'),
    );
    _expectFinderVisibleWithinList(
      tester,
      listKey: 'tv-detail-episode-list',
      itemFinder: find.text('第220集'),
    );
    _expectFinderVisibleWithinList(
      tester,
      listKey: 'tv-detail-episode-group-list',
      itemFinder: find.text('201-220'),
    );

    expect(find.text('暴风资源'), findsOneWidget);
    expect(find.text('第220集'), findsOneWidget);
    expect(find.text('201-220'), findsOneWidget);
  });

  testWidgets('detail focused leading items keep focus border inside list',
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

    Focus.of(tester.element(find.text('主源'))).requestFocus();
    await tester.pumpAndSettle();
    _expectFocusablePaintInsideList(
      tester,
      listKey: 'tv-detail-source-list',
      itemFinder: find.text('主源'),
    );

    Focus.of(tester.element(find.text('第1集'))).requestFocus();
    await tester.pumpAndSettle();
    _expectFocusablePaintInsideList(
      tester,
      listKey: 'tv-detail-episode-list',
      itemFinder: find.text('第1集'),
    );

    Focus.of(tester.element(find.text('推荐影片'))).requestFocus();
    await tester.pumpAndSettle();
    _expectFocusablePaintInsideList(
      tester,
      listKey: 'tv-detail-recommend-list',
      itemFinder: find.text('推荐影片'),
    );
  });

  testWidgets(
      'detail recommend list keeps first focus border after edge return',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '长推荐'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult('source_a', '主源'),
            sources: [
              _searchResult('source_a', '主源'),
            ],
            recommends: List<VideoInfo>.generate(
              14,
              (index) => _videoInfo('recommend_$index', '推荐影片$index'),
            ),
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

    final recommendScrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('tv-detail-recommend-list')),
        matching: find.byType(Scrollable),
      ),
    );
    recommendScrollable.position.jumpTo(
      recommendScrollable.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    expect(
      _detailHorizontalOffset(tester, 'tv-detail-recommend-list'),
      greaterThan(0),
    );

    recommendScrollable.position.jumpTo(
      recommendScrollable.position.minScrollExtent,
    );
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text('推荐影片0'))).requestFocus();
    await tester.pumpAndSettle();

    _expectVideoCardFocusPaintInsideList(
      tester,
      listKey: 'tv-detail-recommend-list',
      itemFinder: find.text('推荐影片0'),
      minLeadingInset: 10,
    );
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

  testWidgets('player select key opens TV fullscreen player', (tester) async {
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
    Focus.of(tester
            .element(find.byKey(const ValueKey('tv-detail-player-entry'))))
        .requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);
  });

  testWidgets('player enter key opens TV fullscreen player', (tester) async {
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
    Focus.of(tester
            .element(find.byKey(const ValueKey('tv-detail-player-entry'))))
        .requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);
  });

  testWidgets('player space key opens TV fullscreen player', (tester) async {
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
    Focus.of(tester
            .element(find.byKey(const ValueKey('tv-detail-player-entry'))))
        .requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

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

    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);
    expect(fullscreenUpdateCount, greaterThan(0));
    expect(fullscreenStartPosition, const Duration(minutes: 9, seconds: 51));
  });

  testWidgets('detail fullscreen overlay reuses preview player controller',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setTvSurfaceSize(tester);
    var controllerCreatedCount = 0;
    var updateDataSourceCount = 0;

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
            if (controllerCreatedCount == 0) {
              controllerCreatedCount += 1;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(minutes: 6),
                  duration: const Duration(minutes: 50),
                  onUpdateDataSource: (_, {startAt, headers}) {
                    updateDataSourceCount += 1;
                  },
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: null,
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(controllerCreatedCount, 1);
    final initialUpdateCount = updateDataSourceCount;

    await tester.tap(find.text('全屏'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);
    expect(controllerCreatedCount, 1);
    expect(updateDataSourceCount, initialUpdateCount);
  });

  testWidgets(
      'shared fullscreen overlay seek still works when preview controller attaches late',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setTvSurfaceSize(tester);
    final controller = _FakeVideoPlayerWidgetController(
      isPlaying: true,
      currentPosition: const Duration(minutes: 6),
      duration: const Duration(minutes: 50),
    );
    var createController = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              children: [
                Expanded(
                  child: TvVideoDetailScreen(
                    videoInfo: _videoInfo('main', '主影片'),
                    loadDetail: (_, __) async => TvVideoDetailData(
                      currentDetail: _searchResult('source_a', '主源'),
                      sources: [
                        _searchResult('source_a', '主源'),
                      ],
                      recommends: const [],
                    ),
                    playerBuilder: (_, onControllerCreated) {
                      if (createController) {
                        onControllerCreated(controller);
                      }
                      return Container(
                        key: const ValueKey('tv-detail-player-placeholder'),
                        color: Colors.black,
                      );
                    },
                    fullscreenPlayerBuilder: null,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => createController = true),
                  child: const Text('attach-controller'),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('全屏'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('attach-controller'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 80));

    expect(controller.seekPositions, isNotEmpty);
  });

  testWidgets('shared fullscreen overlay handles remote keys globally',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setTvSurfaceSize(tester);
    var controllerCreated = false;

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
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(minutes: 6),
                  duration: const Duration(minutes: 50),
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: null,
        ),
      ),
    );

    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text('全屏'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('全屏'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsOneWidget);
  });

  testWidgets(
      'shared fullscreen overlay toggles play pause with enter and space',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setTvSurfaceSize(tester);
    late _FakeVideoPlayerWidgetController controller;
    var controllerCreated = false;

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
            if (!controllerCreated) {
              controllerCreated = true;
              controller = _FakeVideoPlayerWidgetController(
                isPlaying: true,
                currentPosition: const Duration(minutes: 6),
                duration: const Duration(minutes: 50),
              );
              onControllerCreated(controller);
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: null,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('全屏'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.pauseCount, 1);
    expect(controller.playCount, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(controller.playCount, 1);
  });

  testWidgets(
      'shared fullscreen overlay keeps chrome visible on repeated pause toggles',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setTvSurfaceSize(tester);
    late _FakeVideoPlayerWidgetController controller;
    var controllerCreated = false;

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
            if (!controllerCreated) {
              controllerCreated = true;
              controller = _FakeVideoPlayerWidgetController(
                isPlaying: true,
                currentPosition: const Duration(minutes: 6),
                duration: const Duration(minutes: 50),
              );
              onControllerCreated(controller);
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: null,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('全屏'));
    await tester.pumpAndSettle();

    Future<void> expectPauseChrome(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(controller.isPlaying, isFalse);
      expect(
        find.byKey(const ValueKey('tv-fullscreen-top-decorations')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tv-fullscreen-center-play')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tv-fullscreen-bottom-progress')),
        findsOneWidget,
      );
    }

    Future<void> resumeAndSettle(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(controller.isPlaying, isTrue);
    }

    await expectPauseChrome(LogicalKeyboardKey.enter);
    await resumeAndSettle(LogicalKeyboardKey.enter);
    await expectPauseChrome(LogicalKeyboardKey.space);
    await resumeAndSettle(LogicalKeyboardKey.space);
    await expectPauseChrome(LogicalKeyboardKey.enter);
  });

  testWidgets(
      'shared fullscreen overlay switching episode and source updates reused controller',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _setTvSurfaceSize(tester);
    final updateUrls = <String>[];
    late _FakeVideoPlayerWidgetController controller;
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '主影片', totalEpisodes: 3),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 3,
            ),
            sources: [
              _searchResult('source_a', '主源', episodeCount: 3),
              _searchResult('source_b', '备用源', episodeCount: 3),
            ],
            recommends: const [],
          ),
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              controller = _FakeVideoPlayerWidgetController(
                isPlaying: true,
                currentPosition: const Duration(minutes: 6),
                duration: const Duration(minutes: 50),
                onUpdateDataSource: (url, {startAt, headers}) {
                  updateUrls.add(url);
                },
              );
              onControllerCreated(controller);
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: null,
        ),
      ),
    );

    await tester.pumpAndSettle();
    final initialUpdateCount = updateUrls.length;

    await tester.tap(find.text('全屏'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    final fullscreenMenu = find.byKey(const ValueKey('tv-fullscreen-menu'));
    final fullscreenEpisode = find.descendant(
      of: fullscreenMenu,
      matching: find.text('第2集'),
    );
    final fullscreenSourceTab = find.descendant(
      of: fullscreenMenu,
      matching: find.text('播放线路'),
    );
    final fullscreenBackupSource = find.descendant(
      of: fullscreenMenu,
      matching: find.text('备用源'),
    );

    Focus.of(tester.element(fullscreenEpisode)).requestFocus();
    await tester.pumpAndSettle();
    await tester.tap(fullscreenEpisode);
    await tester.pumpAndSettle();

    expect(updateUrls.length, greaterThan(initialUpdateCount));
    expect(updateUrls.last, 'https://example.com/2.m3u8');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    Focus.of(tester.element(fullscreenSourceTab)).requestFocus();
    await tester.pumpAndSettle();
    Focus.of(tester.element(fullscreenBackupSource)).requestFocus();
    await tester.pumpAndSettle();
    await tester.tap(fullscreenBackupSource);
    await tester.pumpAndSettle();

    expect(updateUrls.length, greaterThan(initialUpdateCount + 1));
    expect(updateUrls.last, 'https://example.com/2.m3u8');
  });

  testWidgets('escape closes shared fullscreen overlay without popping detail',
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
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          TvVideoDetailScreen(
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
                        fullscreenPlayerBuilder: null,
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
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
    await tester.tap(find.text('全屏'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('tv-detail-player-entry')), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsNothing);
    expect(find.text('打开详情页'), findsNothing);
  });

  testWidgets('resumes continue watching episode and playback position',
      (tester) async {
    await _setTvSurfaceSize(tester);
    Duration? startPosition;
    String? requestedUrl;
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo(
            'detail_source_a',
            '主影片',
            source: 'source_a',
            sourceName: '主源',
            index: 497,
            totalEpisodes: 500,
            playTime: 497,
            totalTime: 3600,
          ),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 500,
            ),
            sources: [
              _searchResult('source_a', '主源', episodeCount: 500),
            ],
            recommends: const [],
          ),
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(seconds: 497),
                  duration: const Duration(seconds: 3600),
                  onUpdateDataSource: (url, {startAt, headers}) {
                    requestedUrl = url;
                    startPosition = startAt;
                  },
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(requestedUrl, 'https://example.com/497.m3u8');
    expect(startPosition, const Duration(seconds: 497));
  });

  testWidgets('progress listener saves TV play record like mobile player',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await UserDataService.saveIsLocalMode(true);
    addTearDown(() async => UserDataService.saveIsLocalMode(false));
    await _setTvSurfaceSize(tester);

    late _FakeVideoPlayerWidgetController controller;
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo(
            'detail_source_a',
            '主影片',
            source: 'source_a',
            sourceName: '主源',
            index: 497,
            totalEpisodes: 500,
            playTime: 497,
            totalTime: 3600,
          ),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 500,
            ),
            sources: [
              _searchResult('source_a', '主源', episodeCount: 500),
            ],
            recommends: const [],
          ),
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              controller = _FakeVideoPlayerWidgetController(
                isPlaying: true,
                currentPosition: const Duration(seconds: 498),
                duration: const Duration(seconds: 3600),
              );
              onControllerCreated(controller);
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    controller.emitProgress();
    await tester.pump();

    final records = await LocalModeStorageService.getPlayRecords();
    expect(records, hasLength(1));
    expect(records.first.source, 'source_a');
    expect(records.first.id, 'detail_source_a');
    expect(records.first.sourceName, '主源');
    expect(records.first.index, 497);
    expect(records.first.playTime, 498);
    expect(records.first.totalTime, 3600);
  });

  testWidgets('switching TV source saves new record before old one is cleaned',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await UserDataService.saveIsLocalMode(true);
    addTearDown(() async => UserDataService.saveIsLocalMode(false));
    await LocalModeStorageService.savePlayRecord(
      PlayRecord(
        id: 'detail_source_a',
        source: 'source_a',
        title: '主影片',
        sourceName: '主源',
        year: '2026',
        cover: '',
        index: 497,
        totalEpisodes: 500,
        playTime: 497,
        totalTime: 3600,
        saveTime: 1,
        searchTitle: '主影片',
      ),
    );
    await LocalModeStorageService.savePlayRecord(
      PlayRecord(
        id: 'another_video_source',
        source: 'source_x',
        title: '其它影片',
        sourceName: '其它线路',
        year: '2026',
        cover: '',
        index: 12,
        totalEpisodes: 24,
        playTime: 333,
        totalTime: 1800,
        saveTime: 2,
        searchTitle: '其它影片',
      ),
    );
    await _setTvSurfaceSize(tester);

    var controllerCreated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo(
            'detail_source_a',
            '主影片',
            source: 'source_a',
            sourceName: '主源',
            index: 497,
            totalEpisodes: 500,
            playTime: 497,
            totalTime: 3600,
          ),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_a',
              '主源',
              episodeCount: 500,
            ),
            sources: [
              _searchResult('source_a', '主源', episodeCount: 500),
              _searchResult('source_b', '备用源', episodeCount: 500),
            ],
            recommends: const [],
          ),
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(seconds: 777),
                  duration: const Duration(seconds: 3600),
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('备用源'));
    await tester.pumpAndSettle();
    await tester.pump();

    final records = await LocalModeStorageService.getPlayRecords();
    expect(records.where((record) => record.source == 'source_a'), isEmpty);
    expect(
        records.where((record) => record.source == 'source_b'), hasLength(1));
    final switchedRecord =
        records.firstWhere((record) => record.source == 'source_b');
    expect(switchedRecord.id, 'detail_source_b');
    expect(switchedRecord.index, 497);
    expect(switchedRecord.playTime, 777);
    expect(switchedRecord.sourceName, '备用源');
    expect(
      records.where((record) => record.title == '其它影片'),
      hasLength(1),
    );
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

  testWidgets('continue watching waits for saved streaming source before play',
      (tester) async {
    await _setTvSurfaceSize(tester);
    late ValueChanged<List<SearchResult>> emitIncrementalSources;
    final moreSourcesCompleter = Completer<List<SearchResult>>();
    final updatedUrls = <String>[];
    final startPositions = <Duration?>[];
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo(
            'detail_source_saved',
            '主影片',
            source: 'source_saved',
            sourceName: '保存源',
            index: 2,
            totalEpisodes: 10,
            playTime: 120,
            totalTime: 3600,
          ),
          loadInitialSources: (_, __) async => const [],
          loadMoreSources: (_, __, onIncrementalResults) {
            emitIncrementalSources = onIncrementalResults;
            return moreSourcesCompleter.future;
          },
          loadRecommends: (_, __, ___) async => const [],
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: Duration.zero,
                  duration: const Duration(seconds: 3600),
                  onUpdateDataSource: (url, {startAt, headers}) {
                    updatedUrls.add(url);
                    startPositions.add(startAt);
                  },
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pump();
    emitIncrementalSources([
      _searchResult(
        'source_other',
        '其它源',
        episodeCount: 10,
        episodeUrlPrefix: 'https://other.example.com',
      ),
    ]);
    await tester.pump();

    expect(updatedUrls, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    emitIncrementalSources([
      _searchResult(
        'source_other',
        '其它源',
        episodeCount: 10,
        episodeUrlPrefix: 'https://other.example.com',
      ),
      _searchResult(
        'source_saved',
        '保存源',
        episodeCount: 10,
        episodeUrlPrefix: 'https://saved.example.com',
      ),
    ]);
    await tester.pump();
    await tester.pump();

    expect(updatedUrls, ['https://saved.example.com/2.m3u8']);
    expect(startPositions, [const Duration(seconds: 120)]);

    moreSourcesCompleter.complete([
      _searchResult(
        'source_other',
        '其它源',
        episodeCount: 10,
        episodeUrlPrefix: 'https://other.example.com',
      ),
      _searchResult(
        'source_saved',
        '保存源',
        episodeCount: 10,
        episodeUrlPrefix: 'https://saved.example.com',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(updatedUrls, ['https://saved.example.com/2.m3u8']);
  });

  testWidgets('continue watching falls back to same episode count source',
      (tester) async {
    await _setTvSurfaceSize(tester);
    late ValueChanged<List<SearchResult>> emitIncrementalSources;
    final moreSourcesCompleter = Completer<List<SearchResult>>();
    final updatedUrls = <String>[];
    var controllerCreated = false;
    final searchedSources = [
      _searchResult(
        'source_short',
        '短源',
        episodeCount: 8,
        episodeUrlPrefix: 'https://short.example.com',
      ),
      _searchResult(
        'source_same',
        '同集数源',
        episodeCount: 10,
        episodeUrlPrefix: 'https://same.example.com',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo(
            'missing_saved_id',
            '主影片',
            source: 'source_missing',
            sourceName: '失效源',
            index: 4,
            totalEpisodes: 10,
            playTime: 90,
            totalTime: 3600,
          ),
          loadInitialSources: (_, __) async => const [],
          loadMoreSources: (_, __, onIncrementalResults) {
            emitIncrementalSources = onIncrementalResults;
            return moreSourcesCompleter.future;
          },
          loadRecommends: (_, __, ___) async => const [],
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: Duration.zero,
                  duration: const Duration(seconds: 3600),
                  onUpdateDataSource: (url, {startAt, headers}) {
                    updatedUrls.add(url);
                  },
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pump();
    emitIncrementalSources(searchedSources);
    await tester.pump();

    expect(updatedUrls, isEmpty);

    moreSourcesCompleter.complete(searchedSources);
    await tester.pumpAndSettle();

    expect(updatedUrls, ['https://same.example.com/4.m3u8']);
  });

  testWidgets('continue watching falls back to any source without count match',
      (tester) async {
    await _setTvSurfaceSize(tester);
    final moreSourcesCompleter = Completer<List<SearchResult>>();
    final updatedUrls = <String>[];
    var controllerCreated = false;
    final searchedSources = [
      _searchResult(
        'source_short',
        '短源',
        episodeCount: 8,
        episodeUrlPrefix: 'https://short.example.com',
      ),
      _searchResult(
        'source_long',
        '长源',
        episodeCount: 12,
        episodeUrlPrefix: 'https://long.example.com',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo(
            'missing_saved_id',
            '主影片',
            source: 'source_missing',
            sourceName: '失效源',
            index: 4,
            totalEpisodes: 10,
            playTime: 90,
            totalTime: 3600,
          ),
          loadInitialSources: (_, __) async => const [],
          loadMoreSources: (_, __, ___) => moreSourcesCompleter.future,
          loadRecommends: (_, __, ___) async => const [],
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: Duration.zero,
                  duration: const Duration(seconds: 3600),
                  onUpdateDataSource: (url, {startAt, headers}) {
                    updatedUrls.add(url);
                  },
                ),
              );
            }
            return Container(
              key: const ValueKey('tv-detail-player-placeholder'),
              color: Colors.black,
            );
          },
          fullscreenPlayerBuilder: (_, __) => Container(
            key: const ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pump();
    moreSourcesCompleter.complete(searchedSources);
    await tester.pumpAndSettle();

    expect(
      updatedUrls.single,
      isIn({
        'https://short.example.com/4.m3u8',
        'https://long.example.com/4.m3u8',
      }),
    );
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
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          TvVideoDetailScreen(
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
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
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

  testWidgets('global escape pops TV detail page when focus is outside detail',
      (tester) async {
    await _setTvSurfaceSize(tester);
    final outsideFocusNode = FocusNode();
    addTearDown(outsideFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          Stack(
                        children: [
                          TvVideoDetailScreen(
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
                          Focus(
                            focusNode: outsideFocusNode,
                            child: const SizedBox(
                              key: ValueKey('outside-detail-focus-target'),
                              width: 1,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
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

    outsideFocusNode.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('打开详情页'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-detail-player-entry')), findsNothing);
  });
}

Future<void> _expectDetailListStartsScrollingAfterHalf(
  WidgetTester tester, {
  required String listKey,
  required Finder beforeHalfFinder,
  required Finder afterHalfFinder,
}) async {
  Focus.of(tester.element(beforeHalfFinder)).requestFocus();
  await tester.pumpAndSettle();
  final offsetAfterBeforeHalfFocus = _detailHorizontalOffset(tester, listKey);

  Focus.of(tester.element(afterHalfFinder)).requestFocus();
  await tester.pumpAndSettle();
  expect(
    _detailHorizontalOffset(tester, listKey),
    greaterThan(offsetAfterBeforeHalfFocus),
  );
}

double _detailHorizontalOffset(WidgetTester tester, String listKey) {
  final scrollableFinder = find.descendant(
    of: find.byKey(ValueKey(listKey)),
    matching: find.byType(Scrollable),
  );
  final scrollable = tester.state<ScrollableState>(scrollableFinder);
  return scrollable.position.pixels;
}

void _expectFinderVisibleWithinList(
  WidgetTester tester, {
  required String listKey,
  required Finder itemFinder,
}) {
  final listRect = tester.getRect(find.byKey(ValueKey(listKey)));
  final itemRect = tester.getRect(itemFinder);

  expect(itemRect.left, greaterThanOrEqualTo(listRect.left));
  expect(itemRect.right, lessThanOrEqualTo(listRect.right));
}

void _expectFinderNearListLeadingEdge(
  WidgetTester tester, {
  required String listKey,
  required Finder itemFinder,
  double maxLeadingGap = 36,
}) {
  final listRect = tester.getRect(find.byKey(ValueKey(listKey)));
  final itemRect = tester.getRect(itemFinder);
  expect(itemRect.left - listRect.left, lessThanOrEqualTo(maxLeadingGap));
}

void _expectFocusablePaintInsideList(
  WidgetTester tester, {
  required String listKey,
  required Finder itemFinder,
}) {
  final listRect = tester.getRect(find.byKey(ValueKey(listKey)));
  final focusableFinder = find.ancestor(
    of: itemFinder,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is AnimatedContainer ||
          widget.runtimeType.toString() == 'TvVideoCard',
    ),
  );
  final focusableRect = tester.getRect(focusableFinder.first);
  expect(focusableRect.left, greaterThanOrEqualTo(listRect.left + 1));
}

void _expectVideoCardFocusPaintInsideList(
  WidgetTester tester, {
  required String listKey,
  required Finder itemFinder,
  double minLeadingInset = 1,
}) {
  final listRect = tester.getRect(find.byKey(ValueKey(listKey)));
  final cardRect = tester.getRect(
    find
        .ancestor(
          of: itemFinder,
          matching: find.byWidgetPredicate((widget) => widget is TvVideoCard),
        )
        .first,
  );
  final scaledWidth = cardRect.width * TvVideoCard.focusedScale;
  final scaledLeft = cardRect.center.dx - (scaledWidth / 2);
  expect(scaledLeft, greaterThanOrEqualTo(listRect.left + minLeadingInset));
}

ScrollController _detailScrollController(WidgetTester tester) {
  final scrollView = tester.widget<SingleChildScrollView>(
    find.byType(SingleChildScrollView),
  );
  return scrollView.controller!;
}

void _expectFocused(WidgetTester tester, Finder finder) {
  expect(Focus.of(tester.element(finder)).hasFocus, isTrue);
}

void _expectFocusedWithin(WidgetTester tester, Finder finder) {
  expect(
    Focus.of(tester.element(finder)).hasFocus ||
        Focus.of(tester.element(finder)).hasPrimaryFocus,
    isTrue,
  );
}

Future<void> _expectFocusStaysAfterKey(
  WidgetTester tester, {
  required Finder focusFinder,
  required LogicalKeyboardKey key,
}) async {
  Focus.of(tester.element(focusFinder)).requestFocus();
  await tester.pumpAndSettle();
  expect(Focus.of(tester.element(focusFinder)).hasFocus, isTrue);

  await tester.sendKeyEvent(key);
  await tester.pump(const Duration(milliseconds: 80));

  expect(Focus.of(tester.element(focusFinder)).hasFocus, isTrue);
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 12,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsOneWidget);
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
    this.isLoading = false,
    this.onUpdateDataSource,
  });

  static const Duration loadingHoldDuration = Duration(milliseconds: 520);

  @override
  bool isPlaying;

  @override
  Duration? currentPosition;

  @override
  final Duration? duration;

  @override
  bool isLoading;

  final List<VoidCallback> _progressListeners = [];

  final List<Duration> seekPositions = [];

  final FutureOr<void> Function(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  })? onUpdateDataSource;

  @override
  void addProgressListener(VoidCallback listener) {
    if (!_progressListeners.contains(listener)) {
      _progressListeners.add(listener);
    }
  }

  void emitProgress() {
    for (final listener in List<VoidCallback>.from(_progressListeners)) {
      listener();
    }
  }

  @override
  Future<void> dispose() async {}

  @override
  void exitWebFullscreen() {}

  @override
  bool get isPipMode => false;

  @override
  double get playbackSpeed => 1.0;

  @override
  Future<void> pause() async {
    isPlaying = false;
    pauseCount++;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    playCount++;
  }

  @override
  void removeProgressListener(VoidCallback listener) {
    _progressListeners.remove(listener);
  }

  @override
  Future<void> seekTo(Duration position) async {
    currentPosition = position;
    seekPositions.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  void setVideoFit(VideoFitType fitType) {}

  @override
  Future<void> setVolume(double volume) async {}

  int pauseCount = 0;

  int playCount = 0;

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

VideoInfo _videoInfo(
  String id,
  String title, {
  String source = 'test',
  String sourceName = '测试源',
  int index = 1,
  int totalEpisodes = 2,
  int playTime = 0,
  int totalTime = 0,
}) {
  return VideoInfo(
    id: id,
    source: source,
    title: title,
    sourceName: sourceName,
    year: '2026',
    cover: '',
    index: index,
    totalEpisodes: totalEpisodes,
    playTime: playTime,
    totalTime: totalTime,
    saveTime: 0,
    searchTitle: title,
  );
}

SearchResult _searchResult(
  String source,
  String sourceName, {
  int episodeCount = 2,
  List<String>? episodeTitles,
  String episodeUrlPrefix = 'https://example.com',
  String desc = '这是一段详情介绍。',
}) {
  final episodeIndexes = List<int>.generate(episodeCount, (index) => index + 1);
  final resolvedEpisodeTitles =
      episodeTitles ?? episodeIndexes.map((index) => '第$index集').toList();
  return SearchResult(
    id: 'detail_$source',
    title: '主影片',
    poster: '',
    episodes:
        episodeIndexes.map((index) => '$episodeUrlPrefix/$index.m3u8').toList(),
    episodesTitles: resolvedEpisodeTitles,
    source: source,
    sourceName: sourceName,
    year: '2026',
    desc: desc,
  );
}
