// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/search_service.dart';
import 'package:selene/tv_app/services/tv_search_recommend_service.dart';
import 'package:selene/tv_app/services/tv_theme_service.dart';
import 'package:selene/tv_app/screens/tv_search_screen.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';
import 'package:selene/tv_app/widgets/tv_video_grid.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TvSearchRecommendService.clearDebugCache();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.physicalSizeTestValue = const Size(1920, 1080);
    binding.window.devicePixelRatioTestValue = 1;
  });

  tearDown(() {
    TvSearchRecommendService.clearDebugCache();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  });

  testWidgets('renders TV search history and recommendations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['庆余年', '长安的荔枝'],
            hotWords: const [],
            recommends: [_videoInfo('recommend_1', '世界的主人')],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-search-screen')), findsOneWidget);
    expect(find.text('搜索历史'), findsOneWidget);
    expect(find.text('搜索热词'), findsNothing);
    expect(find.text('影片推荐'), findsOneWidget);
    expect(find.text('庆余年'), findsOneWidget);
    expect(find.text('世界的主人'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('tv-search-recommend-list')), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('影片推荐')).dx,
      tester.getTopLeft(find.text('搜索历史')).dx,
    );
    expect(
      tester
          .getTopLeft(
              find.byKey(const ValueKey('tv-video-card-focus-recommend_1')))
          .dx,
      tester.getTopLeft(find.text('影片推荐')).dx,
    );
    expect(
      tester
          .getTopLeft(
              find.byKey(const ValueKey('tv-video-card-focus-recommend_1')))
          .dx,
      tester.getTopLeft(find.text('搜索历史')).dx,
    );
    expect(
      tester
          .widget<GridView>(
            find.byKey(const ValueKey('tv-search-word-grid-搜索历史')),
          )
          .physics,
      isA<NeverScrollableScrollPhysics>(),
    );
  });

  testWidgets('keeps vertical gap between history title and history words',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['庆余年', '长安的荔枝'],
            hotWords: const [],
            recommends: [_videoInfo('recommend_1', '世界的主人')],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final historyTitleBottom = tester.getBottomLeft(find.text('搜索历史')).dy;
    final historyGridTop = tester
        .getTopLeft(find.byKey(const ValueKey('tv-search-word-grid-搜索历史')))
        .dy;

    expect(historyGridTop - historyTitleBottom, greaterThanOrEqualTo(10));
  });

  testWidgets('fills search input from hot word tile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: ['剑来'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('剑来'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tv-search-input')),
        matching: find.text('剑来'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('search page recommends use passive detail cache first',
      (tester) async {
    TvSearchRecommendService.recordDetailRecommends(
      videoInfo: _videoInfo('detail_a', '详情 A'),
      recommends: [
        _videoInfo('recommend_a1', '缓存推荐 A1'),
        _videoInfo('recommend_a2', '缓存推荐 A2'),
      ],
    );
    TvSearchRecommendService.recordDetailRecommends(
      videoInfo: _videoInfo('detail_b', '详情 B'),
      recommends: [
        _videoInfo('recommend_b1', '缓存推荐 B1'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async {
            return TvSearchData(
              searchHistory: const ['庆余年'],
              hotWords: const [],
              recommends: await TvSearchRecommendService.loadSearchRecommends(
                fallbackLoader: () async => [
                  _videoInfo('fallback_1', '兜底推荐 1'),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('缓存推荐 B1'), findsOneWidget);
    expect(find.text('缓存推荐 A1'), findsOneWidget);
    expect(find.text('缓存推荐 A2'), findsOneWidget);
    expect(find.text('兜底推荐 1'), findsNothing);
  });

  testWidgets('search page falls back to hot tv and hot show items',
      (tester) async {
    final fallbackRecommends = [
      ...List<VideoInfo>.generate(
        10,
        (index) => _videoInfo('tv_$index', '剧集$index'),
      ),
      ...List<VideoInfo>.generate(
        10,
        (index) => _videoInfo('show_$index', '综艺$index'),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async {
            return TvSearchData(
              searchHistory: const ['庆余年'],
              hotWords: const [],
              recommends: await TvSearchRecommendService.loadSearchRecommends(
                fallbackLoader: () async => fallbackRecommends,
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    final recommendList = tester.widget<ListView>(
      find.byKey(const ValueKey('tv-search-recommend-list')),
    );

    expect(recommendList.semanticChildCount, fallbackRecommends.length);
    expect(find.text('剧集0'), findsOneWidget);
    expect(fallbackRecommends[9].title, '剧集9');
    expect(fallbackRecommends[10].title, '综艺0');
    expect(fallbackRecommends.last.title, '综艺9');
  });

  testWidgets(
      'shows live suggestion results on the right after choosing initials',
      (tester) async {
    final suggestionQueries = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: ['庆余年'],
            hotWords: ['剑来'],
            recommends: [
              VideoInfo(
                id: 'recommend_1',
                source: 'test',
                title: '推荐影片',
                sourceName: '测试源',
                year: '2026',
                cover: '',
                index: 1,
                totalEpisodes: 1,
                playTime: 0,
                totalTime: 0,
                saveTime: 0,
                searchTitle: '推荐影片',
              )
            ],
          ),
          loadSuggestions: (query) async {
            suggestionQueries.add(query);
            if (query == 'SJ') {
              return const ['世界的主人', '时间的证人', '世界的主人'];
            }
            return const <String>[];
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('S'));
    await tester.pump();
    await tester.tap(find.text('J'));
    await tester.pumpAndSettle();

    expect(suggestionQueries, containsAllInOrder(const ['S', 'SJ']));
    expect(find.byKey(const ValueKey('tv-search-suggestion-panel')),
        findsOneWidget);
    expect(find.text('联想结果'), findsOneWidget);
    expect(find.text('世界的主人'), findsOneWidget);
    expect(find.text('时间的证人'), findsOneWidget);
    expect(find.text('搜索历史'), findsNothing);
    expect(find.text('搜索热词'), findsNothing);
    expect(find.text('影片推荐'), findsOneWidget);
    expect(find.text('推荐影片'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-search-suggestion-grid')),
        findsOneWidget);
  });

  testWidgets('clearing query restores default right side sections',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['庆余年'],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['时间的证人'],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('S'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-search-suggestion-panel')),
        findsOneWidget);

    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('tv-search-suggestion-panel')), findsNothing);
    expect(find.text('搜索历史'), findsOneWidget);
    expect(find.text('搜索热词'), findsNothing);
  });

  testWidgets('suggestion tiles use focus background without white border',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['世界的主人', '时间的证人'],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('S'));
    await tester.pumpAndSettle();

    final suggestionNode = _focusNodeForText(tester, '世界的主人');
    suggestionNode.requestFocus();
    await tester.pumpAndSettle();

    final suggestionContainer = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('世界的主人'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final decoration = suggestionContainer.decoration as BoxDecoration;

    expect(decoration.color, const Color(0xFF5E646E));
    expect(decoration.border, isNull);
  });

  testWidgets('aligns suggestion content with recommendation section',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const [],
            recommends: [_videoInfo('recommend_1', '世界的主人')],
          ),
          loadSuggestions: (_) async => const ['开始推理吧', '开心锤锤'],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('K'));
    await tester.pumpAndSettle();

    final suggestionTitleLeft = tester.getTopLeft(find.text('联想结果')).dx;
    final suggestionTileLeft = tester
        .getTopLeft(
          find.byKey(const ValueKey('tv-search-suggestion-tile-开始推理吧')),
        )
        .dx;
    final recommendTitleLeft = tester.getTopLeft(find.text('影片推荐')).dx;

    expect(suggestionTitleLeft, recommendTitleLeft);
    expect(suggestionTileLeft, recommendTitleLeft);
  });

  testWidgets('pressing a suggestion fills query without starting search',
      (tester) async {
    final searchedQueries = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['庆余年'],
            hotWords: [],
            recommends: [_videoInfo('recommend_1', '推荐影片')],
          ),
          loadSuggestions: (_) async => const ['世界的主人', '时间的证人'],
          loadSearchResults: (query) async {
            searchedQueries.add(query);
            return <SearchResult>[
              SearchResult(
                id: 'video_1',
                title: '世界的主人',
                poster: '',
                episodes: const ['episode-1'],
                episodesTitles: const ['第1集'],
                source: 'test',
                sourceName: '测试源',
                year: '2026',
              ),
            ];
          },
        ),
      ),
    );

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'S',
      suggestion: '世界的主人',
    );
    await tester.pumpAndSettle();

    expect(searchedQueries, isEmpty);
    expect(
      find.byKey(const ValueKey('tv-search-result-grid-panel')),
      findsNothing,
    );
    expect(find.text('搜索历史'), findsOneWidget);
    expect(find.text('影片推荐'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tv-search-suggestion-panel')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tv-search-input')),
        matching: find.text('世界的主人'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('search button starts search with edited suggestion query',
      (tester) async {
    final searchedQueries = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['世界的主人'],
          loadSearchResults: (query) async {
            searchedQueries.add(query);
            return <SearchResult>[
              SearchResult(
                id: 'video_$query',
                title: query,
                poster: '',
                episodes: const ['episode-1'],
                episodesTitles: const ['第1集'],
                source: 'test',
                sourceName: '测试源',
                year: '2026',
              ),
            ];
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'S',
      suggestion: '世界的主人',
    );

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    expect(searchedQueries, ['世界的主']);
    expect(
      find.byKey(const ValueKey('tv-search-result-grid-panel')),
      findsOneWidget,
    );
    expect(find.text('1个影片'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tv-search-input')),
        matching: find.text('世界的主'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pressing history item starts search with enter key',
      (tester) async {
    final searchedQueries = <String>[];

    Future<void> pumpSearchScreen() async {
      await tester.pumpWidget(
        MaterialApp(
          home: TvSearchScreen(
            loadSearchData: (_) async => const TvSearchData(
              searchHistory: ['庆余年'],
              hotWords: [],
              recommends: [],
            ),
            loadSearchResults: (query) async {
              searchedQueries.add(query);
              return <SearchResult>[
                SearchResult(
                  id: 'video_$query',
                  title: query,
                  poster: '',
                  episodes: const ['episode-1'],
                  episodesTitles: const ['第1集'],
                  source: 'test',
                  sourceName: '测试源',
                  year: '2026',
                ),
              ];
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      final historyNode = _focusNodeForText(tester, '庆余年');
      historyNode.requestFocus();
      await tester.pumpAndSettle();
      expect(historyNode.hasFocus, isTrue);
    }

    Future<void> expectHistoryConfirmSearch(LogicalKeyboardKey key) async {
      searchedQueries.clear();
      await pumpSearchScreen();
      await tester.sendKeyDownEvent(key);
      await tester.pump();
      await tester.sendKeyUpEvent(key);
      await _pumpUntil(
        tester,
        condition: () => searchedQueries.isNotEmpty,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(searchedQueries.last, '庆余年');
      expect(find.text('搜索结果'), findsOneWidget);
      expect(find.text('庆余年'), findsWidgets);
    }

    await expectHistoryConfirmSearch(LogicalKeyboardKey.enter);
  });

  testWidgets('pressing history item starts search with space key',
      (tester) async {
    final searchedQueries = <String>[];

    Future<void> pumpSearchScreen() async {
      await tester.pumpWidget(
        MaterialApp(
          home: TvSearchScreen(
            loadSearchData: (_) async => const TvSearchData(
              searchHistory: ['庆余年'],
              hotWords: [],
              recommends: [],
            ),
            loadSearchResults: (query) async {
              searchedQueries.add(query);
              return <SearchResult>[
                SearchResult(
                  id: 'video_$query',
                  title: query,
                  poster: '',
                  episodes: const ['episode-1'],
                  episodesTitles: const ['第1集'],
                  source: 'test',
                  sourceName: '测试源',
                  year: '2026',
                ),
              ];
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      final historyNode = _focusNodeForText(tester, '庆余年');
      historyNode.requestFocus();
      await tester.pumpAndSettle();
      expect(historyNode.hasFocus, isTrue);
    }

    Future<void> expectHistoryConfirmSearch(LogicalKeyboardKey key) async {
      searchedQueries.clear();
      await pumpSearchScreen();
      await tester.sendKeyDownEvent(key);
      await tester.pump();
      await tester.sendKeyUpEvent(key);
      await _pumpUntil(
        tester,
        condition: () => searchedQueries.isNotEmpty,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(searchedQueries.last, '庆余年');
      expect(find.text('搜索结果'), findsOneWidget);
      expect(find.text('庆余年'), findsWidgets);
    }

    await expectHistoryConfirmSearch(LogicalKeyboardKey.space);
  });

  testWidgets('pressing history item starts search with select key',
      (tester) async {
    final searchedQueries = <String>[];

    Future<void> pumpSearchScreen() async {
      await tester.pumpWidget(
        MaterialApp(
          home: TvSearchScreen(
            loadSearchData: (_) async => const TvSearchData(
              searchHistory: ['庆余年'],
              hotWords: [],
              recommends: [],
            ),
            loadSearchResults: (query) async {
              searchedQueries.add(query);
              return <SearchResult>[
                SearchResult(
                  id: 'video_$query',
                  title: query,
                  poster: '',
                  episodes: const ['episode-1'],
                  episodesTitles: const ['第1集'],
                  source: 'test',
                  sourceName: '测试源',
                  year: '2026',
                ),
              ];
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      final historyNode = _focusNodeForText(tester, '庆余年');
      historyNode.requestFocus();
      await tester.pumpAndSettle();
      expect(historyNode.hasFocus, isTrue);
    }

    Future<void> expectHistoryConfirmSearch(LogicalKeyboardKey key) async {
      searchedQueries.clear();
      await pumpSearchScreen();
      await tester.sendKeyDownEvent(key);
      await tester.pump();
      await tester.sendKeyUpEvent(key);
      await _pumpUntil(
        tester,
        condition: () => searchedQueries.isNotEmpty,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(searchedQueries.last, '庆余年');
      expect(find.text('搜索结果'), findsOneWidget);
      expect(find.text('庆余年'), findsWidgets);
    }

    await expectHistoryConfirmSearch(LogicalKeyboardKey.select);
  });

  testWidgets('right arrow on keyboard enters suggestion list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['世界的主人', '时间的证人', '时间的旅人'],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('S'));
    await tester.pumpAndSettle();

    final keyboardFocusNode = _focusNodeForText(tester, 'X');
    keyboardFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(keyboardFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '世界的主人').hasFocus, isTrue);
  });

  testWidgets('right arrow on keyboard enters nearest default right panel item',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['蜡笔小新', '人世间', '幽灵'],
            hotWords: [],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final keyboardFocusNode = _focusNodeForText(tester, 'L');
    keyboardFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(keyboardFocusNode.hasFocus, isTrue);

    final expectedNearestItem = _nearestTextLabelByCenterY(
      tester,
      sourceLabel: 'L',
      candidateLabels: const ['蜡笔小新', '人世间', '幽灵'],
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, expectedNearestItem).hasFocus, isTrue);
  });

  testWidgets('left arrow on suggestion returns focus to left controls',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['世界的主人', '时间的证人', '时间的旅人'],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('S'));
    await tester.pumpAndSettle();

    final leftFocusNode = _focusNodeForText(tester, '删除');
    leftFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(leftFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_focusNodeForText(tester, '世界的主人').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(leftFocusNode.hasFocus, isTrue);
  });

  testWidgets('top row suggestion moves focus up to remembered left control',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['世界的主人', '时间的证人', '时间的旅人'],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('S'));
    await tester.pumpAndSettle();

    final leftFocusNode = _focusNodeForText(tester, '删除');
    leftFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(leftFocusNode.hasFocus, isTrue);

    final topRowSuggestionNode = _focusNodeForText(tester, '时间的证人');
    topRowSuggestionNode.requestFocus();
    await tester.pumpAndSettle();
    expect(topRowSuggestionNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(leftFocusNode.hasFocus, isTrue);
  });

  testWidgets('recommendation focus up returns to remembered suggestion tile',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const [],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
            ],
          ),
          loadSuggestions: (_) async => const ['世界的主人', '时间的证人'],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('S'));
    await tester.pumpAndSettle();

    final suggestionFocusNode = _focusNodeForText(tester, '时间的证人');
    suggestionFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(suggestionFocusNode.hasFocus, isTrue);

    final recommendFocusNode = _focusNodeForText(tester, '推荐 1');
    recommendFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(recommendFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(suggestionFocusNode.hasFocus, isTrue);
  });

  testWidgets('suggestion focus down returns to remembered recommendation tile',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const [],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
            ],
          ),
          loadSuggestions: (_) async => const ['世界的主人', '时间的证人'],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('S'));
    await tester.pumpAndSettle();

    final rememberedRecommendFocusNode = _focusNodeForText(tester, '推荐 2');
    rememberedRecommendFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(rememberedRecommendFocusNode.hasFocus, isTrue);

    final suggestionFocusNode = _focusNodeForText(tester, '时间的证人');
    suggestionFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(suggestionFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(rememberedRecommendFocusNode.hasFocus, isTrue);
  });

  testWidgets('search results aggregate duplicated titles into one card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => <SearchResult>[
            SearchResult(
              id: 'video_1',
              title: '剑来',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_a',
              sourceName: '源A',
              year: '2025',
            ),
            SearchResult(
              id: 'video_2',
              title: '剑来',
              poster: '',
              episodes: const ['episode-1', 'episode-2'],
              episodesTitles: const ['第1集', '第2集'],
              source: 'source_b',
              sourceName: '源B',
              year: '2025',
            ),
            SearchResult(
              id: 'video_3',
              title: '牧神记',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_c',
              sourceName: '源C',
              year: '2025',
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    final resultGridFinder = find.byKey(const ValueKey('tv-video-grid'));
    expect(
      find.descendant(of: resultGridFinder, matching: find.text('剑来')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: resultGridFinder, matching: find.text('牧神记')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: resultGridFinder, matching: find.text('2025 · 2个资源')),
      findsOneWidget,
    );

    final resultGrid = tester.widget<TvVideoGrid>(
      find.byKey(const ValueKey('tv-search-result-grid-panel')),
    );
    expect(resultGrid.crossAxisCount, 5);
    expect(resultGrid.showTitle, isFalse);
    expect(find.text('2个影片'), findsOneWidget);
  });

  testWidgets('shows search progress and fixed aggregated result header',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResultsWithProgress: (
            query, {
            required onPartialResults,
            required onProgress,
          }) async {
            onProgress(
              const SearchProgressSnapshot(
                totalResources: 40,
                completedResources: 12,
                currentResourceName: '测试源 A',
                isComplete: false,
              ),
            );
            onPartialResults(
              <SearchResult>[
                SearchResult(
                  id: 'video_1',
                  title: '剑来',
                  poster: '',
                  episodes: const ['episode-1'],
                  episodesTitles: const ['第1集'],
                  source: 'source_a',
                  sourceName: '源A',
                  year: '2025',
                ),
              ],
            );
            await Future<void>.delayed(const Duration(milliseconds: 1));
            onProgress(
              const SearchProgressSnapshot(
                totalResources: 40,
                completedResources: 40,
                currentResourceName: '测试源 B',
                isComplete: true,
              ),
            );
            onPartialResults(
              <SearchResult>[
                SearchResult(
                  id: 'video_1',
                  title: '剑来',
                  poster: '',
                  episodes: const ['episode-1'],
                  episodesTitles: const ['第1集'],
                  source: 'source_a',
                  sourceName: '源A',
                  year: '2025',
                ),
                SearchResult(
                  id: 'video_2',
                  title: '牧神记',
                  poster: '',
                  episodes: const ['episode-1'],
                  episodesTitles: const ['第1集'],
                  source: 'source_b',
                  sourceName: '源B',
                  year: '2025',
                ),
              ],
            );
            return <SearchResult>[
              SearchResult(
                id: 'video_1',
                title: '剑来',
                poster: '',
                episodes: const ['episode-1'],
                episodesTitles: const ['第1集'],
                source: 'source_a',
                sourceName: '源A',
                year: '2025',
              ),
              SearchResult(
                id: 'video_2',
                title: '牧神记',
                poster: '',
                episodes: const ['episode-1'],
                episodesTitles: const ['第1集'],
                source: 'source_b',
                sourceName: '源B',
                year: '2025',
              ),
            ];
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('tv-search-result-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-search-result-progress')),
        findsOneWidget);
    expect(find.text('已搜索 40/40 个资源站'), findsOneWidget);
    expect(find.text('2个影片'), findsOneWidget);
    expect(find.text('搜索结果'), findsOneWidget);
  });

  testWidgets('aligns search result header with first video card edge',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => <SearchResult>[
            SearchResult(
              id: 'video_1',
              title: '剑来',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_a',
              sourceName: '源A',
              year: '2025',
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    final headerLeft = tester.getTopLeft(find.text('搜索结果')).dx;
    final firstCardLeft = tester
        .getTopLeft(find.byKey(const ValueKey('tv-video-card-focus-video_1')))
        .dx;

    expect(headerLeft, firstCardLeft);
  });

  testWidgets('keeps search home content aligned with search result content',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['庆余年'],
            hotWords: const [],
            recommends: [_videoInfo('recommend_1', '世界的主人')],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => <SearchResult>[
            SearchResult(
              id: 'video_1',
              title: '剑来',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_a',
              sourceName: '源A',
              year: '2025',
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    final searchHomeSectionLeft = tester.getTopLeft(find.text('搜索历史')).dx;
    final searchHomeRecommendCardLeft = tester
        .getTopLeft(
            find.byKey(const ValueKey('tv-video-card-focus-recommend_1')))
        .dx;

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    final searchResultHeaderLeft = tester.getTopLeft(find.text('搜索结果')).dx;
    final searchResultCardLeft = tester
        .getTopLeft(find.byKey(const ValueKey('tv-video-card-focus-video_1')))
        .dx;

    expect(searchHomeSectionLeft, searchResultHeaderLeft);
    expect(searchHomeRecommendCardLeft, searchResultCardLeft);
  });

  testWidgets('pins search result header above result grid content',
      (tester) async {
    final results = List<SearchResult>.generate(
      20,
      (index) => SearchResult(
        id: 'video_$index',
        title: '结果$index',
        poster: '',
        episodes: const ['episode-1'],
        episodesTitles: const ['第1集'],
        source: 'source_$index',
        sourceName: '源$index',
        year: '2025',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => results,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    final headerBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('tv-search-result-header')))
        .dy;
    final firstCardTop = tester
        .getTopLeft(find.byKey(const ValueKey('tv-video-card-focus-video_0')))
        .dy;

    expect(firstCardTop, greaterThan(headerBottom));
  });

  testWidgets('search result header includes top cover mask', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => <SearchResult>[
            SearchResult(
              id: 'video_1',
              title: '剑来',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_a',
              sourceName: '源A',
              year: '2025',
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    final headerSize =
        tester.getSize(find.byKey(const ValueKey('tv-search-result-header')));
    expect(headerSize.height, greaterThan(40));
  });

  testWidgets('search result panel keeps a 10 pixel bottom inset',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => <SearchResult>[
            SearchResult(
              id: 'video_1',
              title: '剑来',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_a',
              sourceName: '源A',
              year: '2025',
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    final screenBottom =
        tester.getBottomLeft(find.byKey(const ValueKey('tv-search-screen'))).dy;
    final resultPanelBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('tv-search-result-panel')))
        .dy;

    expect(screenBottom - resultPanelBottom, moreOrLessEquals(10));
  });

  testWidgets('shows wipe skeletons before first search results arrive',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResultsWithProgress: (
            query, {
            required onPartialResults,
            required onProgress,
          }) async {
            onProgress(
              const SearchProgressSnapshot(
                totalResources: 40,
                completedResources: 3,
                currentResourceName: '测试源 A',
                isComplete: false,
              ),
            );
            await Future<void>.delayed(const Duration(milliseconds: 50));
            onPartialResults(
              <SearchResult>[
                SearchResult(
                  id: 'video_1',
                  title: '剑来',
                  poster: '',
                  episodes: const ['episode-1'],
                  episodesTitles: const ['第1集'],
                  source: 'source_a',
                  sourceName: '源A',
                  year: '2025',
                ),
              ],
            );
            return <SearchResult>[
              SearchResult(
                id: 'video_1',
                title: '剑来',
                poster: '',
                episodes: const ['episode-1'],
                episodesTitles: const ['第1集'],
                source: 'source_a',
                sourceName: '源A',
                year: '2025',
              ),
            ];
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('tv-search-result-initial-skeleton-grid')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tv-search-result-loading-skeleton')),
      findsWidgets,
    );

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('tv-search-result-initial-skeleton-grid')),
      findsNothing,
    );
    expect(find.text('1个影片'), findsOneWidget);
  });

  testWidgets('shows all aggregated search results without local truncation',
      (tester) async {
    final searchResults = List<SearchResult>.generate(
      20,
      (index) => SearchResult(
        id: 'video_$index',
        title: '结果$index',
        poster: '',
        episodes: const ['episode-1'],
        episodesTitles: const ['第1集'],
        source: 'source_$index',
        sourceName: '源$index',
        year: '2025',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => searchResults,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    final resultGrid = tester.widget<TvVideoGrid>(
      find.byKey(const ValueKey('tv-search-result-grid-panel')),
    );
    expect(resultGrid.videos.length, 20);
    expect(resultGrid.hasMore, isFalse);
    expect(resultGrid.onLoadMore, isNull);
    expect(resultGrid.crossAxisSpacing, 18);
  });

  testWidgets('search result grid renders only first batch initially',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => List<SearchResult>.generate(
            120,
            (index) => SearchResult(
              id: 'video_$index',
              title: '结果$index',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_$index',
              sourceName: '源$index',
              year: '2025',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    expect(_videoGridRenderedChildCount(tester), 80);
  });

  testWidgets(
      'search result aggregation cache reuses grouped videos during progress-only rebuilds',
      (tester) async {
    final progressSignals = <void Function()>[];

    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResultsWithProgress: (query,
              {required onPartialResults, required onProgress}) async {
            final partialResults = List<SearchResult>.generate(
              2,
              (index) => SearchResult(
                id: 'video_$index',
                title: '结果$index',
                poster: '',
                episodes: const ['episode-1'],
                episodesTitles: const ['第1集'],
                source: 'source_$index',
                sourceName: '源$index',
                year: '2025',
              ),
            );

            onPartialResults(partialResults);
            onProgress(
              const SearchProgressSnapshot(
                totalResources: 3,
                completedResources: 1,
                currentResourceName: '资源站 1',
                isComplete: false,
              ),
            );
            progressSignals.add(() {
              onProgress(
                const SearchProgressSnapshot(
                  totalResources: 3,
                  completedResources: 2,
                  currentResourceName: '资源站 2',
                  isComplete: false,
                ),
              );
            });

            await Future<void>.delayed(const Duration(milliseconds: 1));
            return partialResults;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('tv-search-result-grid-panel')),
    );

    final initialResultGrid = tester.widget<TvVideoGrid>(
      find.byKey(const ValueKey('tv-search-result-grid-panel')),
    );

    expect(progressSignals, hasLength(1));
    progressSignals.single();
    await tester.pump();

    final rebuiltResultGrid = tester.widget<TvVideoGrid>(
      find.byKey(const ValueKey('tv-search-result-grid-panel')),
    );

    expect(
        identical(rebuiltResultGrid.videos, initialResultGrid.videos), isTrue);
  });

  testWidgets(
      'leftmost search result first moves focus to nearest keyboard edge',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => List<SearchResult>.generate(
            5,
            (index) => SearchResult(
              id: 'video_$index',
              title: '结果$index',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_$index',
              sourceName: '源$index',
              year: '2025',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    final firstResultNode = _focusNodeForText(tester, '结果0');
    firstResultNode.requestFocus();
    await tester.pumpAndSettle();
    expect(firstResultNode.hasFocus, isTrue);

    final expectedNearestKey = _nearestLabelByCenterY(
      tester,
      sourceLabel: '结果0',
      candidateLabels: const ['F', 'L', 'R', 'X', '4', '0'],
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, expectedNearestKey).hasFocus, isTrue);
  });

  testWidgets('autofocuses first search result card after entering result page',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => List<SearchResult>.generate(
            6,
            (index) => SearchResult(
              id: 'video_$index',
              title: '结果$index',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_$index',
              sourceName: '源$index',
              year: '2025',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '结果0').hasFocus, isTrue);
  });

  testWidgets('first left from search results moves to nearest keyboard bridge',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => List<SearchResult>.generate(
            20,
            (index) => SearchResult(
              id: 'video_$index',
              title: '结果$index',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_$index',
              sourceName: '源$index',
              year: '2025',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    final firstResultNode = _focusNodeForText(tester, '结果0');
    firstResultNode.requestFocus();
    await tester.pumpAndSettle();
    expect(firstResultNode.hasFocus, isTrue);

    final expectedNearestKey = _nearestLabelByCenterY(
      tester,
      sourceLabel: '结果0',
      candidateLabels: const ['F', 'L', 'R', 'X', '4', '0'],
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, expectedNearestKey).hasFocus, isTrue);
  });

  testWidgets(
      'later left from search results restores last remembered left control',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => List<SearchResult>.generate(
            20,
            (index) => SearchResult(
              id: 'video_$index',
              title: '结果$index',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_$index',
              sourceName: '源$index',
              year: '2025',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    final firstResultNode = _focusNodeForText(tester, '结果0');
    firstResultNode.requestFocus();
    await tester.pumpAndSettle();
    final expectedNearestKey = _nearestLabelByCenterY(
      tester,
      sourceLabel: '结果0',
      candidateLabels: const ['F', 'L', 'R', 'X', '4', '0'],
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_focusNodeForText(tester, expectedNearestKey).hasFocus, isTrue);

    final zeroFocusNode = _focusNodeForText(tester, '0');
    zeroFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(zeroFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(firstResultNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(zeroFocusNode.hasFocus, isTrue);
  });

  testWidgets('top four search results keep focus on arrow up', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['剑来'],
          loadSearchResults: (_) async => List<SearchResult>.generate(
            8,
            (index) => SearchResult(
              id: 'video_$index',
              title: '结果$index',
              poster: '',
              episodes: const ['episode-1'],
              episodesTitles: const ['第1集'],
              source: 'source_$index',
              sourceName: '源$index',
              year: '2025',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'J',
      suggestion: '剑来',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    for (var index = 0; index < 4; index++) {
      final focusNode = _focusNodeForText(tester, '结果$index');
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(focusNode.hasFocus, isTrue);
    }
  });

  testWidgets('clears search history through TV confirm dialog',
      (tester) async {
    var history = <String>['庆余年', '长安的荔枝'];
    final themeService = TvThemeService()
      ..setThemeKey(TvThemePalette.netflixRedKey);

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: themeService,
          child: TvSearchScreen(
            loadSearchData: (_) async => TvSearchData(
              searchHistory: history,
              hotWords: const ['剑来'],
              recommends: [],
            ),
            onClearSearchHistory: (_) async {
              history = <String>[];
              return true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-search-history-clear-button')),
        findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('tv-search-history-clear-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-confirm-dialog')), findsOneWidget);
    expect(find.text('清空搜索历史'), findsOneWidget);
    expect(find.text('确定要清空全部搜索记录吗？'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('tv-confirm-dialog'))),
      const Size(372, 182),
    );
    expect(
      (tester
              .widget<AnimatedContainer>(
                find.byKey(const ValueKey('tv-confirm-cancel-button')),
              )
              .decoration as BoxDecoration)
          .color,
      TvThemePalette.netflixRed.accent,
    );

    await tester.tap(find.byKey(const ValueKey('tv-confirm-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.text('庆余年'), findsNothing);
    expect(find.text('长安的荔枝'), findsNothing);
    expect(find.text('暂无搜索历史'), findsOneWidget);
  });

  testWidgets('throttles repeat focus traversal on text word tiles',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: ['热词1', '热词2', '热词3'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final firstFocusNode = _focusNodeForText(tester, '热词1');
    final secondFocusNode = _focusNodeForText(tester, '热词2');
    final thirdFocusNode = _focusNodeForText(tester, '热词3');

    firstFocusNode.requestFocus();
    await tester.pump();
    expect(firstFocusNode.hasFocus, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(secondFocusNode.hasFocus, isTrue);

    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(secondFocusNode.hasFocus, isTrue);

    await tester.pump(const Duration(milliseconds: 180));
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(thirdFocusNode.hasFocus, isTrue);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
  });

  testWidgets('rightmost word tiles keep focus on right key', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['历史1', '历史2', '历史3', '历史4'],
            hotWords: ['热词1', '热词2', '热词3'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final rightmostHistoryNode = _focusNodeForText(tester, '历史3');
    rightmostHistoryNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 80));
    expect(rightmostHistoryNode.hasFocus, isTrue);

    final raggedRightNode = _focusNodeForText(tester, '历史4');
    raggedRightNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 80));
    expect(raggedRightNode.hasFocus, isTrue);
  });

  testWidgets('last hot word moves focus down to first recommendation card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const ['热词1', '热词2', '热词3', '热词4'],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final lastHotWordFocusNode = _focusNodeForText(tester, '热词4');
    lastHotWordFocusNode.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '推荐 1').hasFocus, isTrue);
    expect(lastHotWordFocusNode.hasFocus, isFalse);
  });

  testWidgets(
      'last history item moves focus down to remembered recommendation card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: ['历史1', '历史2', '历史3', '历史4'],
            hotWords: const [],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final historyFocusNode = _focusNodeForText(tester, '历史4');
    historyFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(historyFocusNode.hasFocus, isTrue);

    final rememberedRecommendFocusNode = _focusNodeForText(tester, '推荐 2');
    rememberedRecommendFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(rememberedRecommendFocusNode.hasFocus, isTrue);

    historyFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(historyFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(rememberedRecommendFocusNode.hasFocus, isTrue);
    expect(_focusNodeForText(tester, 'A').hasFocus, isFalse);
  });

  testWidgets('last history item falls back to first recommendation card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: ['历史1', '历史2', '历史3', '历史4'],
            hotWords: const [],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final historyFocusNode = _focusNodeForText(tester, '历史4');
    historyFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(historyFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '推荐 1').hasFocus, isTrue);
  });

  testWidgets(
      'last hot word keeps focus on arrow down when recommendations are empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['历史1'],
            hotWords: ['热词1', '热词2', '热词3', '热词4'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final hotWordFocusNode = _focusNodeForText(tester, '热词4');
    hotWordFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(hotWordFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(hotWordFocusNode.hasFocus, isTrue);
    expect(_focusNodeForText(tester, 'A').hasFocus, isFalse);
  });

  testWidgets('leftmost recommendation card moves focus left to search panel',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const ['热词1'],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final keyboardFocusNode = _focusNodeForText(tester, 'A');
    keyboardFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(keyboardFocusNode.hasFocus, isTrue);

    final firstRecommendFocusNode = _focusNodeForText(tester, '推荐 1');
    firstRecommendFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(firstRecommendFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(keyboardFocusNode.hasFocus, isTrue);
    expect(firstRecommendFocusNode.hasFocus, isFalse);
  });

  testWidgets('top keyboard row wraps up to nearest bottom action button',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    const candidateActionKeys = <Key>[
      ValueKey('tv-search-left-clear-button'),
      ValueKey('tv-search-left-submit-button'),
      ValueKey('tv-search-left-delete-button'),
    ];

    for (final keyLabel in const ['A', 'D', 'F']) {
      final focusNode = _focusNodeForText(tester, keyLabel);
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);

      final expectedActionKey = _nearestActionKeyByCenterX(
        tester,
        sourceLabel: keyLabel,
        candidateKeys: candidateActionKeys,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(_focusNodeForKey(tester, expectedActionKey).hasFocus, isTrue);
    }
  });

  testWidgets('action buttons move focus down to top keyboard row',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    const actionKeys = <Key>[
      ValueKey('tv-search-left-clear-button'),
      ValueKey('tv-search-left-submit-button'),
      ValueKey('tv-search-left-delete-button'),
    ];

    for (final actionKey in actionKeys) {
      final focusNode = _focusNodeForKey(tester, actionKey);
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);

      final expectedKeyLabel = _nearestLabelByCenterX(
        tester,
        sourceKey: actionKey,
        candidateLabels: const ['A', 'B', 'C', 'D', 'E', 'F'],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_focusNodeForText(tester, expectedKeyLabel).hasFocus, isTrue);
    }
  });

  testWidgets('action buttons wrap up to bottom keyboard row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: [],
            hotWords: [],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    const actionKeys = <Key>[
      ValueKey('tv-search-left-clear-button'),
      ValueKey('tv-search-left-submit-button'),
      ValueKey('tv-search-left-delete-button'),
    ];

    for (final actionKey in actionKeys) {
      final focusNode = _focusNodeForKey(tester, actionKey);
      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);

      final expectedKeyLabel = _nearestLabelByCenterX(
        tester,
        sourceKey: actionKey,
        candidateLabels: const ['5', '6', '7', '8', '9', '0'],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(_focusNodeForText(tester, expectedKeyLabel).hasFocus, isTrue);
    }
  });

  testWidgets('history clear button moves down to first history item',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1', '历史2', '历史3'],
            hotWords: const [],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final clearButtonFocusNode = _focusNodeForKey(
        tester, const ValueKey('tv-search-history-clear-button'));
    clearButtonFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(clearButtonFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '历史1').hasFocus, isTrue);
  });

  testWidgets(
      'history clear button falls back to remembered recommendation when history is empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const [],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
              _videoInfo('recommend_3', '推荐 3'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final rememberedRecommendNode = _focusNodeForText(tester, '推荐 2');
    rememberedRecommendNode.requestFocus();
    await tester.pumpAndSettle();
    expect(rememberedRecommendNode.hasFocus, isTrue);

    final clearButtonFocusNode = _focusNodeForKey(
        tester, const ValueKey('tv-search-history-clear-button'));
    clearButtonFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(clearButtonFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(rememberedRecommendNode.hasFocus, isTrue);
  });

  testWidgets('last recommendation card moves focus up to remembered hot word',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1', '历史2'],
            hotWords: const ['热词1', '热词2', '热词3', '热词4'],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
              _videoInfo('recommend_3', '推荐 3'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final rememberedHotWordNode = _focusNodeForText(tester, '热词4');
    rememberedHotWordNode.requestFocus();
    await tester.pumpAndSettle();
    expect(rememberedHotWordNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusNodeForText(tester, '推荐 1').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_focusNodeForText(tester, '推荐 3').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(rememberedHotWordNode.hasFocus, isTrue);
    expect(_focusNodeForText(tester, '推荐 3').hasFocus, isFalse);
  });

  testWidgets('recommendation focus up prefers hot words over history memory',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1', '历史2', '历史3', '历史4'],
            hotWords: const ['热词1', '热词2', '热词3', '热词4'],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
              _videoInfo('recommend_3', '推荐 3'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final rememberedHotWordNode = _focusNodeForText(tester, '热词4');
    rememberedHotWordNode.requestFocus();
    await tester.pumpAndSettle();
    expect(rememberedHotWordNode.hasFocus, isTrue);

    final historyNode = _focusNodeForText(tester, '历史4');
    historyNode.requestFocus();
    await tester.pumpAndSettle();
    expect(historyNode.hasFocus, isTrue);

    final recommendFocusNode = _focusNodeForText(tester, '推荐 3');
    recommendFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(recommendFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(rememberedHotWordNode.hasFocus, isTrue);
    expect(historyNode.hasFocus, isFalse);
    expect(recommendFocusNode.hasFocus, isFalse);
  });

  testWidgets(
      'recommendation card moves focus up to history when hot words are empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1', '历史2', '历史3', '历史4'],
            hotWords: const [],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final rememberedHistoryNode = _focusNodeForText(tester, '历史4');
    rememberedHistoryNode.requestFocus();
    await tester.pumpAndSettle();
    expect(rememberedHistoryNode.hasFocus, isTrue);

    final recommendFocusNode = _focusNodeForText(tester, '推荐 2');
    recommendFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(recommendFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(rememberedHistoryNode.hasFocus, isTrue);
    expect(recommendFocusNode.hasFocus, isFalse);
  });

  testWidgets('recommendation cards keep focus on arrow down', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1', '历史2'],
            hotWords: const ['热词1', '热词2', '热词3'],
            recommends: [
              _videoInfo('recommend_1', '推荐 1'),
              _videoInfo('recommend_2', '推荐 2'),
              _videoInfo('recommend_3', '推荐 3'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final middleRecommendNode = _focusNodeForText(tester, '推荐 2');
    middleRecommendNode.requestFocus();
    await tester.pumpAndSettle();
    expect(middleRecommendNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(middleRecommendNode.hasFocus, isTrue);
  });

  testWidgets('right panel scroll keeps focused word near middle',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: List<String>.generate(15, (index) => '历史$index'),
            hotWords: List<String>.generate(12, (index) => '热词$index'),
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final lowerWordNode = _focusNodeForText(tester, '热词8');
    lowerWordNode.requestFocus();
    await tester.pumpAndSettle();

    final focusedRect = tester.getRect(find.text('热词8'));
    final viewportHeight = tester.view.physicalSize.height;
    expect(focusedRect.center.dy, greaterThan(viewportHeight * 0.36));
    expect(focusedRect.center.dy, lessThan(viewportHeight * 0.64));
  });

  testWidgets('suggestion focus keeps right panel still before recommendations',
      (tester) async {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.physicalSizeTestValue = const Size(1280, 720);
    addTearDown(() {
      binding.window.physicalSizeTestValue = const Size(1920, 1080);
    });

    final longSuggestions = List<String>.generate(
      12,
      (index) => '联想结果超长标题$index联想结果超长标题',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const [],
            recommends: List<VideoInfo>.generate(
              6,
              (index) => _videoInfo('recommend_$index', '推荐$index'),
            ),
          ),
          loadSuggestions: (_) async => longSuggestions,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('L'));
    await tester.pumpAndSettle();

    final scrollViewFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.controller != null &&
          widget.controller!.hasClients,
    );
    final scrollViewBefore =
        tester.widget<SingleChildScrollView>(scrollViewFinder.last);
    final beforeOffset = scrollViewBefore.controller!.offset;

    final lowerSuggestionNode = _focusNodeForText(tester, longSuggestions.last);
    lowerSuggestionNode.requestFocus();
    await tester.pumpAndSettle();

    final scrollViewAfter =
        tester.widget<SingleChildScrollView>(scrollViewFinder.last);
    final afterOffset = scrollViewAfter.controller!.offset;

    expect(afterOffset, beforeOffset);
  });

  testWidgets('right panel scrolls down when recommendation card gains focus',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: List<String>.generate(18, (index) => '历史$index'),
            hotWords: List<String>.generate(15, (index) => '热词$index'),
            recommends: List<VideoInfo>.generate(
              6,
              (index) => _videoInfo('recommend_$index', '推荐$index'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final scrollViewFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.controller != null &&
          widget.controller!.hasClients,
    );
    final scrollViewBefore =
        tester.widget<SingleChildScrollView>(scrollViewFinder.last);
    final beforeOffset = scrollViewBefore.controller!.offset;

    final recommendFocusNode = _focusNodeForText(tester, '推荐0');
    recommendFocusNode.requestFocus();
    await tester.pumpAndSettle();

    final scrollViewAfter =
        tester.widget<SingleChildScrollView>(scrollViewFinder.last);
    final afterOffset = scrollViewAfter.controller!.offset;

    expect(afterOffset, greaterThan(beforeOffset));
  });

  testWidgets('moving up from recommendations reveals suggestion header again',
      (tester) async {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.physicalSizeTestValue = const Size(1280, 720);
    addTearDown(() {
      binding.window.physicalSizeTestValue = const Size(1920, 1080);
    });

    final longSuggestions = List<String>.generate(
      8,
      (index) => '联想结果超长标题$index联想结果超长标题',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const [],
            recommends: List<VideoInfo>.generate(
              6,
              (index) => _videoInfo('recommend_$index', '推荐$index'),
            ),
          ),
          loadSuggestions: (_) async => longSuggestions,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('L'));
    await tester.pumpAndSettle();

    final lastSuggestionNode = _focusNodeForText(tester, longSuggestions.last);
    lastSuggestionNode.requestFocus();
    await tester.pumpAndSettle();
    expect(lastSuggestionNode.hasFocus, isTrue);

    final recommendNode = _focusNodeForText(tester, '推荐0');
    recommendNode.requestFocus();
    await tester.pumpAndSettle();
    expect(recommendNode.hasFocus, isTrue);

    final scrollViewFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.controller != null &&
          widget.controller!.hasClients,
    );
    final scrollViewBeforeUp =
        tester.widget<SingleChildScrollView>(scrollViewFinder.last);
    final beforeUpOffset = scrollViewBeforeUp.controller!.offset;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    final scrollViewAfterUp =
        tester.widget<SingleChildScrollView>(scrollViewFinder.last);
    final afterUpOffset = scrollViewAfterUp.controller!.offset;
    final suggestionTitleTop = tester.getTopLeft(find.text('联想结果')).dy;

    expect(lastSuggestionNode.hasFocus, isTrue);
    expect(afterUpOffset, lessThan(beforeUpOffset));
    expect(suggestionTitleTop, greaterThanOrEqualTo(0));
  });

  testWidgets(
      'first recommendation card realigns with section title after moving back from right',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1'],
            hotWords: const [],
            recommends: List<VideoInfo>.generate(
              8,
              (index) => _videoInfo('recommend_$index', '推荐$index'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final recommendListFinder =
        find.byKey(const ValueKey('tv-search-recommend-list'));
    final recommendListBefore = tester.widget<ListView>(recommendListFinder);

    recommendListBefore.controller!.jumpTo(
      recommendListBefore.controller!.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();

    final firstRecommendFocusNode = _focusNodeForText(tester, '推荐0');
    firstRecommendFocusNode.requestFocus();
    await tester.pumpAndSettle();

    final recommendListAfter = tester.widget<ListView>(recommendListFinder);
    final titleLeft = tester.getTopLeft(find.text('影片推荐')).dx;
    final firstCardLeft = tester
        .getTopLeft(
            find.byKey(const ValueKey('tv-video-card-focus-recommend_0')))
        .dx;

    expect(recommendListAfter.controller!.offset, 0);
    expect(firstCardLeft, titleLeft);
  });

  testWidgets('recommendation list keeps focused card pinned to second slot',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1'],
            hotWords: const [],
            recommends: List<VideoInfo>.generate(
              10,
              (index) => _videoInfo('recommend_$index', '推荐$index'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final recommendListFinder =
        find.byKey(const ValueKey('tv-search-recommend-list'));
    final recommendList = tester.widget<ListView>(recommendListFinder);
    final controller = recommendList.controller!;
    final titleLeft = tester.getTopLeft(find.text('影片推荐')).dx;
    final secondSlotLeft = titleLeft + TvVideoCard.width + 24;
    const cardStride = TvVideoCard.width + 24;

    final secondCardFocusNode = _focusNodeForText(tester, '推荐1');
    secondCardFocusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('tv-video-card-focus-recommend_1')),
          )
          .dx,
      secondSlotLeft,
    );

    final thirdCardFocusNode = _focusNodeForText(tester, '推荐2');
    thirdCardFocusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(cardStride, 0.01));
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('tv-video-card-focus-recommend_2')),
          )
          .dx,
      closeTo(secondSlotLeft, 0.01),
    );

    final fourthCardFocusNode = _focusNodeForText(tester, '推荐3');
    fourthCardFocusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(cardStride * 2, 0.01));
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('tv-video-card-focus-recommend_3')),
          )
          .dx,
      closeTo(secondSlotLeft, 0.01),
    );
  });

  testWidgets('recommendation list masks the leading gutter while scrolling',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['历史1'],
            hotWords: const [],
            recommends: List<VideoInfo>.generate(
              10,
              (index) => _videoInfo('recommend_$index', '推荐$index'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final thirdCardFocusNode = _focusNodeForText(tester, '推荐2');
    thirdCardFocusNode.requestFocus();
    await tester.pumpAndSettle();

    final leadingMaskFinder =
        find.byKey(const ValueKey('tv-search-recommend-leading-mask'));
    final leadingMaskRect = tester.getRect(leadingMaskFinder);

    expect(leadingMaskFinder, findsOneWidget);
    expect(leadingMaskRect.width, 24);
  });

  testWidgets('places search panels closer to top on first screen',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['庆余年'],
            hotWords: ['剑来'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final leftTop = tester
        .getTopLeft(find.byKey(const ValueKey('tv-search-page-title')))
        .dy;
    final historyTop = tester.getTopLeft(find.text('搜索历史')).dy;
    expect(leftTop, lessThanOrEqualTo(64));
    expect(historyTop, lessThanOrEqualTo(64));
    expect((leftTop - historyTop).abs(), lessThanOrEqualTo(6));
  });

  testWidgets('left search controls use tighter sizing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['庆余年'],
            hotWords: ['剑来'],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final titleText = tester.widget<Text>(
      find.byKey(const ValueKey('tv-search-page-title')),
    );
    final hintText = tester.widget<Text>(find.text('按返回键可退出本页面'));
    final keyboardGrid = tester.widget<GridView>(
      find.byKey(const ValueKey('tv-search-keyboard')),
    );
    final searchField = tester.widget<Container>(
      find.byKey(const ValueKey('tv-search-input')),
    );
    final clearButton = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('tv-search-left-clear-button')),
    );

    final keyboardDelegate =
        keyboardGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(titleText.style?.fontSize, 28);
    expect(hintText.style?.fontSize, 15);
    expect(
        searchField.constraints?.maxHeight ??
            searchField.constraints?.minHeight,
        46);
    expect(keyboardDelegate.mainAxisExtent, 42);
    expect(
        clearButton.constraints?.maxHeight ??
            clearButton.constraints?.minHeight,
        46);
  });

  testWidgets('search screen paints opaque top status area background',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['庆余年'],
            hotWords: [],
            recommends: [],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final safeArea = tester.widget<SafeArea>(find.byType(SafeArea).first);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final rootColoredBox = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey('tv-search-screen')),
            matching: find.byType(ColoredBox),
          )
          .first,
    );

    expect(safeArea.top, isFalse);
    expect(scaffold.backgroundColor, TvThemeBackground.deepBlue.color);
    expect(rootColoredBox.color, TvThemeBackground.deepBlue.color);
  });

  testWidgets('search result header follows global TV background color',
      (tester) async {
    final themeService = TvThemeService()
      ..setBackgroundKey(TvThemeBackground.deepBlackKey);

    await tester.pumpWidget(
      MaterialApp(
        home: TvTheme(
          service: themeService,
          child: TvSearchScreen(
            loadSearchData: (_) async => const TvSearchData(
              searchHistory: [],
              hotWords: [],
              recommends: [],
            ),
            loadSuggestions: (_) async => const ['人世间'],
            loadSearchResultsWithProgress: (
              query, {
              required onPartialResults,
              required onProgress,
            }) async {
              onProgress(
                const SearchProgressSnapshot(
                  totalResources: 1,
                  completedResources: 1,
                  currentResourceName: '测试源',
                  isComplete: true,
                ),
              );
              onPartialResults(
                <SearchResult>[
                  SearchResult(
                    title: '人世间',
                    year: '2024',
                    sourceName: '源一',
                    source: 'source_1',
                    id: 'video_1',
                    poster: '',
                    episodes: ['第1集'],
                    episodesTitles: ['第1集'],
                  ),
                ],
              );
              return <SearchResult>[
                SearchResult(
                  title: '人世间',
                  year: '2024',
                  sourceName: '源一',
                  source: 'source_1',
                  id: 'video_1',
                  poster: '',
                  episodes: ['第1集'],
                  episodesTitles: ['第1集'],
                ),
              ];
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'R',
      suggestion: '人世间',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('tv-search-result-header')),
    );

    expect(header.color, TvThemeBackground.deepBlack.color);
  });

  testWidgets('right search panels use more compact sizing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['庆余年', '长安的荔枝'],
            hotWords: const ['剑来', '主角', '黑袍纠察队第五季'],
            recommends: [_videoInfo('recommend_1', '世界的主人')],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final historyTitle = tester.widget<Text>(find.text('搜索历史'));
    final hotWordTitle = tester.widget<Text>(find.text('搜索热词'));
    final recommendTitle = tester.widget<Text>(find.text('影片推荐'));
    final historyGrid = tester.widget<GridView>(
      find.byKey(const ValueKey('tv-search-word-grid-搜索历史')),
    );
    final historyTileText = tester.widget<Text>(find.text('庆余年'));
    final recommendList = tester.widget<ListView>(
      find.byKey(const ValueKey('tv-search-recommend-list')),
    );

    final historyDelegate =
        historyGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

    expect(historyTitle.style?.fontSize, 24);
    expect(hotWordTitle.style?.fontSize, 24);
    expect(recommendTitle.style?.fontSize, 26);
    expect(historyDelegate.mainAxisExtent, 46);
    expect(historyDelegate.crossAxisSpacing, 16);
    expect(historyDelegate.mainAxisSpacing, 14);
    expect(historyTileText.style?.fontSize, 17);
    expect(recommendList.padding, const EdgeInsets.fromLTRB(48, 12, 118, 18));
    expect(recommendList.clipBehavior, Clip.hardEdge);
  });

  testWidgets('autofocuses first search history item when history exists',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const ['庆余年', '长安的荔枝'],
            hotWords: const ['剑来', '主角'],
            recommends: [_videoInfo('recommend_1', '世界的主人')],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '庆余年').hasFocus, isTrue);
  });

  testWidgets('autofocuses first hot word when history is empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const ['剑来', '主角'],
            recommends: [_videoInfo('recommend_1', '世界的主人')],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '剑来').hasFocus, isTrue);
  });

  testWidgets('autofocuses first recommendation card when words are empty',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const [],
            recommends: [
              _videoInfo('recommend_1', '世界的主人'),
              _videoInfo('recommend_2', '飞驰人生'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(_focusNodeForText(tester, '世界的主人').hasFocus, isTrue);
  });

  testWidgets('recommendation cards use TV card focus scale and edge feedback',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => TvSearchData(
            searchHistory: const [],
            hotWords: const [],
            recommends: List.generate(
              3,
              (index) => _videoInfo('recommend_$index', '推荐 $index'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-edge-shake')), findsWidgets);
    final focusNode = _focusNodeForText(tester, '推荐 2');
    focusNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    final focusedScale = tester.widget<AnimatedScale>(
      find.ancestor(
        of: find.text('推荐 2'),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(focusedScale.scale, TvVideoCard.focusedScale);
  });

  testWidgets('escape pops TV search page like remote back key',
      (tester) async {
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
                          TvSearchScreen(
                        loadSearchData: (_) async => const TvSearchData(
                          searchHistory: ['庆余年'],
                          hotWords: ['剑来'],
                          recommends: [],
                        ),
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开搜索页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开搜索页'));
    await tester.pumpAndSettle();

    final hotWordFocusNode = _focusNodeForText(tester, '剑来');
    hotWordFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(hotWordFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('打开搜索页'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-search-screen')), findsNothing);
  });

  testWidgets('escape returns search results page to search home first',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['庆余年'],
            hotWords: [],
            recommends: [],
          ),
          loadSearchResults: (_) async => [
            SearchResult(
              id: 'result_1',
              title: '一人之下',
              poster: '',
              url: 'https://example.com/a',
              episodesTitles: [],
              source: 'source_a',
              sourceName: '源 A',
              year: '2024',
              doubanId: 1,
              episodes: [],
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('庆余年'));
    await tester.pumpAndSettle();

    expect(find.text('搜索结果'), findsOneWidget);
    expect(find.text('一人之下'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-search-screen')), findsOneWidget);
    expect(find.text('搜索结果'), findsNothing);
    expect(find.text('搜索历史'), findsOneWidget);
  });

  testWidgets('escape returns suggestion page to search home first',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['庆余年'],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['时间的证人'],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('S'));
    await tester.pumpAndSettle();

    expect(find.text('联想结果'), findsOneWidget);
    expect(find.text('时间的证人'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-search-screen')), findsOneWidget);
    expect(find.text('联想结果'), findsNothing);
    expect(find.text('搜索历史'), findsOneWidget);
  });

  testWidgets('escape returns search results back to previous suggestion page',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['庆余年'],
            hotWords: [],
            recommends: [],
          ),
          loadSuggestions: (_) async => const ['蜡笔小新', '拉布拉多警长'],
          loadSearchResults: (query) async => [
            SearchResult(
              id: 'result_$query',
              title: query,
              poster: '',
              url: 'https://example.com/$query',
              episodesTitles: const [],
              source: 'source_a',
              sourceName: '源 A',
              year: '2024',
              doubanId: 1,
              episodes: const [],
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _fillQueryFromSuggestion(
      tester,
      keyLabel: 'L',
      suggestion: '拉布拉多警长',
    );
    await _tapSearchButton(tester);
    await tester.pumpAndSettle();

    expect(find.text('搜索结果'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tv-search-input')),
        matching: find.text('拉布拉多警长'),
      ),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('联想结果'), findsOneWidget);
    expect(find.text('搜索结果'), findsNothing);
    expect(find.text('拉布拉多警长'), findsOneWidget);
    expect(find.text('蜡笔小新'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tv-search-input')),
        matching: find.text('L'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'escape clears in-flight search progress and stale aggregated results before returning home',
      (tester) async {
    final progressCompleter = Completer<List<SearchResult>>();

    await tester.pumpWidget(
      MaterialApp(
        home: TvSearchScreen(
          loadSearchData: (_) async => const TvSearchData(
            searchHistory: ['庆余年'],
            hotWords: [],
            recommends: [],
          ),
          loadSearchResultsWithProgress: (
            query, {
            required onPartialResults,
            required onProgress,
          }) {
            onProgress(
              const SearchProgressSnapshot(
                totalResources: 9,
                completedResources: 4,
                currentResourceName: '测试源 A',
                isComplete: false,
              ),
            );
            onPartialResults(
              <SearchResult>[
                SearchResult(
                  id: 'result_partial_a',
                  title: '旧结果 A',
                  poster: '',
                  url: 'https://example.com/partial-a',
                  episodesTitles: const [],
                  source: 'source_a',
                  sourceName: '源 A',
                  year: '2024',
                  doubanId: 1,
                  episodes: const [],
                ),
                SearchResult(
                  id: 'result_partial_b',
                  title: '旧结果 B',
                  poster: '',
                  url: 'https://example.com/partial-b',
                  episodesTitles: const [],
                  source: 'source_b',
                  sourceName: '源 B',
                  year: '2024',
                  doubanId: 2,
                  episodes: const [],
                ),
              ],
            );
            return progressCompleter.future;
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('庆余年'));
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('tv-search-result-progress')),
    );
    await tester.pump();

    expect(find.text('搜索结果'), findsOneWidget);
    expect(find.text('2个影片'), findsOneWidget);
    expect(find.text('已搜索 4/9 个资源站'), findsOneWidget);
    expect(find.text('旧结果 A'), findsOneWidget);
    expect(find.text('旧结果 B'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('搜索历史'), findsOneWidget);
    expect(find.text('搜索结果'), findsNothing);
    expect(find.text('2个影片'), findsNothing);
    expect(find.text('已搜索 4/9 个资源站'), findsNothing);
    expect(find.text('旧结果 A'), findsNothing);
    expect(find.text('旧结果 B'), findsNothing);

    progressCompleter.complete(
      <SearchResult>[
        SearchResult(
          id: 'result_final',
          title: '过期结果',
          poster: '',
          url: 'https://example.com/final',
          episodesTitles: const [],
          source: 'source_final',
          sourceName: '源 Final',
          year: '2025',
          doubanId: 3,
          episodes: const [],
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('搜索历史'), findsOneWidget);
    expect(find.text('搜索结果'), findsNothing);
    expect(find.text('过期结果'), findsNothing);
    expect(find.text('已搜索 4/9 个资源站'), findsNothing);
  });

  testWidgets('escape pops TV search page without waiting for extra frame',
      (tester) async {
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
                          TvSearchScreen(
                        loadSearchData: (_) async => const TvSearchData(
                          searchHistory: ['庆余年'],
                          hotWords: ['剑来'],
                          recommends: [],
                        ),
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开搜索页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开搜索页'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('打开搜索页'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-search-screen')), findsNothing);
  });
}

Future<void> _fillQueryFromSuggestion(
  WidgetTester tester, {
  required String keyLabel,
  required String suggestion,
}) async {
  await tester.tap(
    find
        .descendant(
          of: find.byKey(const ValueKey('tv-search-keyboard')),
          matching: find.text(keyLabel),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(ValueKey('tv-search-suggestion-tile-$suggestion')),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSearchButton(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('tv-search-left-submit-button')));
  await tester.pump();
}

FocusNode _focusNodeForText(WidgetTester tester, String label) {
  final focusFinder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Focus &&
          widget.focusNode != null &&
          widget.focusNode!.debugLabel != 'tv-back-handler',
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

FocusNode _focusNodeForKey(WidgetTester tester, Key key) {
  final focusFinder = find.ancestor(
    of: find.byKey(key),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Focus &&
          widget.focusNode != null &&
          widget.focusNode!.debugLabel != 'tv-back-handler',
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

Key _nearestActionKeyByCenterX(
  WidgetTester tester, {
  required String sourceLabel,
  required List<Key> candidateKeys,
}) {
  final sourceCenterX = tester.getRect(find.text(sourceLabel)).center.dx;
  Key? nearestKey;
  double? minDistance;
  for (final candidateKey in candidateKeys) {
    final distance =
        (sourceCenterX - tester.getRect(find.byKey(candidateKey)).center.dx)
            .abs();
    if (minDistance == null || distance < minDistance) {
      minDistance = distance;
      nearestKey = candidateKey;
    }
  }
  return nearestKey!;
}

String _nearestLabelByCenterX(
  WidgetTester tester, {
  required Key sourceKey,
  required List<String> candidateLabels,
}) {
  final sourceCenterX = tester.getRect(find.byKey(sourceKey)).center.dx;
  String? nearestLabel;
  double? minDistance;
  for (final candidateLabel in candidateLabels) {
    final distance =
        (sourceCenterX - tester.getRect(find.text(candidateLabel)).center.dx)
            .abs();
    if (minDistance == null || distance < minDistance) {
      minDistance = distance;
      nearestLabel = candidateLabel;
    }
  }
  return nearestLabel!;
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 30,
}) async {
  for (var index = 0; index < maxPumps; index++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsOneWidget);
}

Future<void> _pumpUntil(
  WidgetTester tester, {
  required bool Function() condition,
  int maxPumps = 30,
}) async {
  for (var index = 0; index < maxPumps; index++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (condition()) {
      return;
    }
  }
  expect(condition(), isTrue);
}

String _nearestLabelByCenterY(
  WidgetTester tester, {
  required String sourceLabel,
  required List<String> candidateLabels,
}) {
  final sourceCenterY = tester
      .getRect(find.byKey(const ValueKey('tv-video-card-focus-video_0')))
      .center
      .dy;
  String? nearestLabel;
  double? minDistance;
  for (final label in candidateLabels) {
    final candidateCenterY = tester.getRect(find.text(label)).center.dy;
    final distance = (sourceCenterY - candidateCenterY).abs();
    if (minDistance == null || distance < minDistance) {
      minDistance = distance;
      nearestLabel = label;
    }
  }
  return nearestLabel!;
}

String _nearestTextLabelByCenterY(
  WidgetTester tester, {
  required String sourceLabel,
  required List<String> candidateLabels,
}) {
  final sourceCenterY = tester.getRect(find.text(sourceLabel)).center.dy;
  String? nearestLabel;
  double? minDistance;
  for (final label in candidateLabels) {
    final candidateCenterY = tester.getRect(find.text(label)).center.dy;
    final distance = (sourceCenterY - candidateCenterY).abs();
    if (minDistance == null || distance < minDistance) {
      minDistance = distance;
      nearestLabel = label;
    }
  }
  return nearestLabel!;
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
    totalEpisodes: 1,
    playTime: 0,
    totalTime: 0,
    saveTime: 0,
    searchTitle: title,
  );
}

int _videoGridRenderedChildCount(WidgetTester tester) {
  final sliverGrid =
      tester.widget<SliverGrid>(find.byKey(const ValueKey('tv-video-grid')));
  final delegate = sliverGrid.delegate as SliverChildBuilderDelegate;
  return delegate.childCount ?? 0;
}
