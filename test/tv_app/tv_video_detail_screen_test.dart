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

  testWidgets('player down key enters first source instead of selected source',
      (tester) async {
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

    Focus.of(tester
            .element(find.byKey(const ValueKey('tv-detail-player-entry'))))
        .requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _expectFocused(tester, find.text('线路一'));
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

  testWidgets('detail row transitions always enter target row from first item',
      (tester) async {
    await _setTvSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: TvVideoDetailScreen(
          videoInfo: _videoInfo('main', '长剧集'),
          loadDetail: (_, __) async => TvVideoDetailData(
            currentDetail: _searchResult(
              'source_c',
              '线路三',
              episodeCount: 25,
            ),
            sources: [
              _searchResult('source_a', '线路一', episodeCount: 25),
              _searchResult('source_b', '线路二', episodeCount: 25),
              _searchResult('source_c', '线路三', episodeCount: 25),
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
    _expectFocused(tester, find.text('第1集'));

    Focus.of(tester.element(find.text('第5集'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('1-20'));

    Focus.of(tester.element(find.text('推荐影片二'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _expectFocused(tester, find.text('1-20'));
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

  testWidgets(
      'detail option rows wait until focus passes half viewport to scroll',
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

    await _expectDetailListStartsScrollingAfterHalf(
      tester,
      listKey: 'tv-detail-source-list',
      beforeHalfFinder: find.text('线路05超长名称用于固定宽度'),
      afterHalfFinder: find.text('线路06超长名称用于固定宽度'),
    );
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

Future<void> _expectDetailListStartsScrollingAfterHalf(
  WidgetTester tester, {
  required String listKey,
  required Finder beforeHalfFinder,
  required Finder afterHalfFinder,
}) async {
  final offsetBeforeFocus = _detailHorizontalOffset(tester, listKey);
  expect(offsetBeforeFocus, 0);

  Focus.of(tester.element(beforeHalfFinder)).requestFocus();
  await tester.pumpAndSettle();
  expect(_detailHorizontalOffset(tester, listKey), 0);

  Focus.of(tester.element(afterHalfFinder)).requestFocus();
  await tester.pumpAndSettle();
  expect(_detailHorizontalOffset(tester, listKey), greaterThan(0));
}

double _detailHorizontalOffset(WidgetTester tester, String listKey) {
  final scrollableFinder = find.descendant(
    of: find.byKey(ValueKey(listKey)),
    matching: find.byType(Scrollable),
  );
  final scrollable = tester.state<ScrollableState>(scrollableFinder);
  return scrollable.position.pixels;
}

void _expectFocused(WidgetTester tester, Finder finder) {
  expect(Focus.of(tester.element(finder)).hasFocus, isTrue);
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
    this.onUpdateDataSource,
  });

  @override
  final bool isPlaying;

  @override
  final Duration? currentPosition;

  @override
  final Duration? duration;

  final List<VoidCallback> _progressListeners = [];

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
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  void removeProgressListener(VoidCallback listener) {
    _progressListeners.remove(listener);
  }

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
