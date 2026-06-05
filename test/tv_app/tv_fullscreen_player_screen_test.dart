import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/play_record.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/services/local_mode_storage_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/screens/tv_fullscreen_player_screen.dart';
import 'package:selene/tv_app/widgets/tv_edge_shake.dart';
import 'package:selene/tv_app/widgets/tv_video_card.dart';
import 'package:selene/widgets/player_settings_panel.dart';
import 'package:selene/widgets/video_player_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserDataService.debugResetMemoryCaches();
  });

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

  testWidgets('opens TV player menu with remote menu keys', (tester) async {
    for (final menuKey in <LogicalKeyboardKey>[
      LogicalKeyboardKey.contextMenu,
    ]) {
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
      expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsNothing);

      await tester.sendKeyEvent(menuKey);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('menu keeps top decorations visible', (tester) async {
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
    expect(find.byKey(const ValueKey('tv-fullscreen-top-decorations')),
        findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-fullscreen-top-decorations')),
        findsOneWidget);
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

  testWidgets('primary menu row keeps vertical position across secondary menus',
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

    final episodeMenuTop = _menuButtonRect(tester, '播放列表').top;

    _focusNodeForMenuLabel(tester, '其它').requestFocus();
    await tester.pumpAndSettle();
    final otherMenuTop = _menuButtonRect(tester, '播放列表').top;

    _focusNodeForMenuLabel(tester, '画面比例').requestFocus();
    await tester.pumpAndSettle();
    final fitMenuTop = _menuButtonRect(tester, '播放列表').top;

    // 二级菜单高度变化时，底部一级菜单行不能上下跳动。
    expect(otherMenuTop, closeTo(episodeMenuTop, 0.5));
    expect(fitMenuTop, closeTo(episodeMenuTop, 0.5));
  });

  testWidgets('non episode secondary menus keep compact top padding',
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

    _focusNodeForMenuLabel(tester, '播放线路').requestFocus();
    await tester.pumpAndSettle();
    final sourceMenuGap = _menuButtonRect(tester, '主线路').top -
        tester.getRect(find.byKey(const ValueKey('tv-fullscreen-menu'))).top;

    _focusNodeForMenuLabel(tester, '画面比例').requestFocus();
    await tester.pumpAndSettle();
    final fitMenuGap = _menuButtonRect(tester, '适应').top -
        tester.getRect(find.byKey(const ValueKey('tv-fullscreen-menu'))).top;

    // 非选集二级菜单内容较短时，弹框顶部应跟随内容高度收紧。
    expect(sourceMenuGap, lessThanOrEqualTo(44));
    expect(fitMenuGap, lessThanOrEqualTo(44));
  });

  testWidgets('menu interactions do not rebuild fullscreen player layer',
      (tester) async {
    var playerBuildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
            _searchResult('source_b', '备用线路'),
          ],
          playerBuilder: (_, __) {
            playerBuildCount++;
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    final settledPlayerBuildCount = playerBuildCount;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('tv-fullscreen-menu')),
        matching:
            find.byKey(const ValueKey('tv-fullscreen-menu-repaint-boundary')),
      ),
      findsOneWidget,
    );
    expect(playerBuildCount, settledPlayerBuildCount);

    _focusNodeForMenuLabel(tester, '播放线路').requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('备用线路'), findsOneWidget);
    expect(playerBuildCount, settledPlayerBuildCount);
  });

  testWidgets('renders fullscreen player before ad filter preference resolves',
      (tester) async {
    final adFilterCompleter = Completer<bool>();
    bool? resolvedAdFilterEnabled;
    final testHooks = TvFullscreenPlayerScreenTestHooks()
      ..onAdFilterResolved = (value) {
        resolvedAdFilterEnabled = value;
      };

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          loadAdFilterEnabled: () => adFilterCompleter.future,
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
          testHooks: testHooks,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const ValueKey('tv-fullscreen-player-placeholder')),
      findsOneWidget,
    );
    expect(resolvedAdFilterEnabled, isTrue);

    adFilterCompleter.complete(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(
      find.byKey(const ValueKey('tv-fullscreen-player-placeholder')),
      findsOneWidget,
    );
    expect(resolvedAdFilterEnabled, isFalse);
  });

  testWidgets(
      'reused fullscreen player renders immediately without waiting ad filter preference',
      (tester) async {
    final adFilterCompleter = Completer<bool>();

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          reuseExistingPlayer: true,
          loadAdFilterEnabled: () => adFilterCompleter.future,
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byKey(const ValueKey('tv-fullscreen-player-placeholder')),
        findsOneWidget);
  });

  testWidgets('primary and other menu keep current vertical focus context',
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

    _focusNodeForMenuLabel(tester, '其它').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForMenuLabel(tester, '片尾 00:00').requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForMenuLabel(tester, '其它').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(_focusNodeForMenuLabel(tester, '片尾 00:00').hasFocus, isTrue);
  });

  testWidgets('source primary tab up focuses nearest source instead of memory',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 3),
          currentDetail: _searchResult(
            'source_a',
            '左侧线路一',
            episodeCount: 3,
          ),
          sources: [
            _searchResult('source_a', '左侧线路一', episodeCount: 3),
            _searchResult('source_b', '中间线路二', episodeCount: 3),
            _searchResult('source_c', '右侧线路三', episodeCount: 3),
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

    _focusNodeForMenuLabel(tester, '播放线路').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForMenuLabel(tester, '右侧线路三').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForMenuLabel(tester, '播放线路').hasFocus, isTrue);

    final nearestSource = _nearestMenuLabelByHorizontalCenter(
      tester,
      anchorLabel: '播放线路',
      candidateLabels: const ['左侧线路一', '中间线路二', '右侧线路三'],
    );
    expect(nearestSource, isNot('右侧线路三'));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(_focusNodeForMenuLabel(tester, nearestSource).hasFocus, isTrue);
  });

  testWidgets('play list primary tab up focuses current episode',
      (tester) async {
    final detail = _searchResult(
      'source_a',
      '主线路',
      episodeCount: 25,
      selectedEpisodeIndex: 21,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            index: 22,
            totalEpisodes: 25,
          ),
          currentDetail: detail,
          sources: [detail],
          initialEpisodeIndex: 21,
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

    _focusNodeForMenuLabel(tester, '播放列表').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForMenuLabel(tester, '21-25').requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForMenuLabel(tester, '播放列表').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(_focusNodeForMenuLabel(tester, '第22集').hasFocus, isTrue);
  });

  testWidgets('episode and group rows use nearest vertical focus',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 25),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 25,
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeCount: 25,
            ),
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

    _focusNodeForMenuLabel(tester, '第3集').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusNodeForMenuLabel(tester, '第3集').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusNodeForMenuLabel(tester, '01-20').hasFocus, isTrue);

    _focusNodeForMenuLabel(tester, '01-20').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusNodeForMenuLabel(tester, '第3集').hasFocus, isTrue);

    _focusNodeForMenuLabel(tester, '第12集').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusNodeForMenuLabel(tester, '01-20').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusNodeForMenuLabel(tester, '第12集').hasFocus, isTrue);

    _focusNodeForMenuLabel(tester, '21-25').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    _focusNodeForMenuLabel(tester, '21-25').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusNodeForMenuLabel(tester, '第21集').hasFocus, isTrue);

    _focusNodeForMenuLabel(tester, '21-25').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusNodeForMenuLabel(tester, '播放列表').hasFocus, isTrue);
  });

  testWidgets('group row arrow up focuses nearest episode after quick switch',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 25),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 25,
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeCount: 25,
            ),
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

    _focusNodeForMenuLabel(tester, '21-25').requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(
      _focusedMenuLabelIn(
        tester,
        const ['第21集', '第22集', '第23集', '第24集', '第25集'],
      ),
      isNotNull,
    );
  });

  testWidgets('switching episode updates player data source and title',
      (tester) async {
    final updatedUrls = <String>[];
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 3),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 3,
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeCount: 3,
            ),
          ],
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(seconds: 8),
                  duration: const Duration(seconds: 1000),
                  onUpdateDataSource: (url, {headers, startAt}) async {
                    updatedUrls.add(url);
                  },
                ),
              );
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    updatedUrls.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _focusNodeForMenuLabel(tester, '第2集').requestFocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('第2集'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));

    expect(updatedUrls, contains('https://example.com/2.m3u8'));
    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsNothing);
  });

  testWidgets('reselecting current episode does not reload player data source',
      (tester) async {
    final updatedUrls = <String>[];
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 3),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 3,
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeCount: 3,
            ),
          ],
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(seconds: 8),
                  duration: const Duration(seconds: 1000),
                  onUpdateDataSource: (url, {headers, startAt}) async {
                    updatedUrls.add(url);
                  },
                ),
              );
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    updatedUrls.clear();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    _focusNodeForMenuLabel(tester, '第1集').requestFocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('第1集'));
    await tester.pumpAndSettle();

    expect(updatedUrls, isEmpty);
    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsNothing);
  });

  testWidgets('fullscreen player auto plays next episode after completion',
      (tester) async {
    final updatedUrls = <String>[];
    final testHooks = TvFullscreenPlayerScreenTestHooks();
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 3),
          testHooks: testHooks,
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 3,
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeCount: 3,
            ),
          ],
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(seconds: 66),
                  duration: const Duration(seconds: 1000),
                  onUpdateDataSource: (url, {startAt, headers}) async {
                    updatedUrls.add(url);
                  },
                ),
              );
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    updatedUrls.clear();

    testHooks.onVideoCompleted?.call();
    await tester.pumpAndSettle();

    expect(updatedUrls, ['https://example.com/2.m3u8']);
  });

  testWidgets('switching source hides menu immediately', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 3),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 3,
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeCount: 3,
            ),
            _searchResult(
              'source_b',
              '备用线路',
              episodeCount: 3,
            ),
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

    _focusNodeForMenuLabel(tester, '播放线路').requestFocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('备用线路'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _focusNodeForMenuLabel(tester, '播放线路').requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('备用线路'), findsOneWidget);
  });

  testWidgets('source menu shows episode counts sorted descending',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 45),
          currentDetail: _searchResult(
            'source_a',
            '暴风资源',
            episodeCount: 45,
          ),
          sources: [
            _searchResult(
              'source_a',
              '暴风资源',
              episodeCount: 45,
            ),
            _searchResult(
              'source_b',
              '最大资源',
              episodeCount: 99,
            ),
            _searchResult(
              'source_c',
              '短资源',
              episodeCount: 12,
            ),
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
    _focusNodeForMenuLabel(tester, '播放线路').requestFocus();
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

  testWidgets('menu auto hides after five seconds of inactivity',
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

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsNothing);
  });

  testWidgets('episode and group rows keep focused item near same leading edge',
      (tester) async {
    final detail = _searchResult(
      'source_a',
      '主线路',
      episodeCount: 120,
      selectedEpisodeIndex: 20,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            index: 21,
            totalEpisodes: 120,
          ),
          currentDetail: detail,
          sources: [detail],
          initialEpisodeIndex: 20,
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

    _focusNodeForMenuLabel(tester, '21-40').requestFocus();
    await tester.pumpAndSettle();
    _expectFinderNearListLeadingEdge(
      tester,
      listKey: 'tv-fullscreen-episode-group-list',
      itemFinder: find.text('21-40'),
      maxLeadingGap: 36,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    _expectMenuButtonNearListLeadingEdge(
      tester,
      listKey: 'tv-fullscreen-episode-list',
      itemFinder: find.text('第21集'),
      maxLeadingGap: 36,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusNodeForMenuLabel(tester, '21-40').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_focusNodeForMenuLabel(tester, '01-20').hasFocus, isTrue);
    _expectFinderNearListLeadingEdge(
      tester,
      listKey: 'tv-fullscreen-episode-group-list',
      itemFinder: find.text('01-20'),
      maxLeadingGap: 36,
    );
  });

  testWidgets('episode group row keeps scroll position on vertical focus moves',
      (tester) async {
    final detail = _searchResult(
      'source_a',
      '主线路',
      episodeCount: 120,
      selectedEpisodeIndex: 20,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            index: 21,
            totalEpisodes: 120,
          ),
          currentDetail: detail,
          sources: [detail],
          initialEpisodeIndex: 20,
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

    _focusNodeForMenuLabel(tester, '21-40').requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('第21集'), findsOneWidget);

    final groupScrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('tv-fullscreen-episode-group-list')),
    );
    final groupController = groupScrollView.controller!;
    final shiftedOffset = (groupController.offset + 40)
        .clamp(0.0, groupController.position.maxScrollExtent);
    groupController.jumpTo(shiftedOffset);
    await tester.pump();

    final nearestEpisode = _nearestMenuLabelByHorizontalCenter(
      tester,
      anchorLabel: '21-40',
      candidateLabels: List<String>.generate(
        20,
        (index) => '第${21 + index}集',
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusNodeForMenuLabel(tester, nearestEpisode).hasFocus, isTrue);

    final nearestGroup = _nearestMenuLabelByHorizontalCenter(
      tester,
      anchorLabel: nearestEpisode,
      candidateLabels: const ['01-20', '21-40', '41-60', '61-80', '81-100'],
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(_focusNodeForMenuLabel(tester, nearestGroup).hasFocus, isTrue);
    expect(groupController.offset, moreOrLessEquals(shiftedOffset));
  });

  testWidgets('episode row keeps scroll position on vertical focus moves',
      (tester) async {
    final detail = _searchResult(
      'source_a',
      '主线路',
      episodeCount: 120,
      selectedEpisodeIndex: 20,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            index: 21,
            totalEpisodes: 120,
          ),
          currentDetail: detail,
          sources: [detail],
          initialEpisodeIndex: 20,
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

    _focusNodeForMenuLabel(tester, '第21集').requestFocus();
    await tester.pumpAndSettle();

    final episodeScrollView = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('tv-fullscreen-episode-list')),
    );
    final episodeController = episodeScrollView.controller!;
    final shiftedOffset = (episodeController.offset + 40)
        .clamp(0.0, episodeController.position.maxScrollExtent);
    episodeController.jumpTo(shiftedOffset);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(_focusNodeForMenuLabel(tester, '第21集').hasFocus, isTrue);
    expect(episodeController.offset, moreOrLessEquals(shiftedOffset));
  });

  testWidgets('play list splits long episodes into grouped pages',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            totalEpisodes: 41,
          ),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 41,
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeCount: 41,
            ),
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

    expect(find.byKey(const ValueKey('tv-fullscreen-episode-list')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('tv-fullscreen-episode-group-list')),
        findsOneWidget);
    expect(find.text('01-20'), findsOneWidget);
    expect(find.text('21-40'), findsOneWidget);
    expect(find.text('41-41'), findsOneWidget);

    expect(find.text('第1集'), findsOneWidget);
    for (var index = 1; index <= 20; index++) {
      expect(find.text('第$index集'), findsOneWidget);
    }
    expect(find.text('第21集'), findsNothing);

    await tester.tap(find.text('21-40'));
    await tester.pumpAndSettle();

    expect(find.text('第21集'), findsOneWidget);
    expect(find.text('第40集'), findsOneWidget);
    expect(find.text('第1集'), findsNothing);
  });

  testWidgets('episode row right key enters next group first episode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            totalEpisodes: 45,
          ),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 45,
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeCount: 45,
            ),
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

    _focusNodeForMenuLabel(tester, '第20集').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('第20集'), findsNothing);
    expect(find.text('第21集'), findsOneWidget);
    expect(_focusNodeForMenuLabel(tester, '第21集').hasFocus, isTrue);
  });

  testWidgets('episode row left key enters previous group last episode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            totalEpisodes: 45,
          ),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 45,
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeCount: 45,
            ),
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

    _focusNodeForMenuLabel(tester, '第20集').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(_focusNodeForMenuLabel(tester, '第21集').hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(find.text('第21集'), findsNothing);
    expect(find.text('第20集'), findsOneWidget);
    expect(_focusNodeForMenuLabel(tester, '第20集').hasFocus, isTrue);
  });

  testWidgets(
      'episode row left key from initial second group focuses episode 20',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            index: 21,
            totalEpisodes: 45,
          ),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 45,
            selectedEpisodeIndex: 20,
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeCount: 45,
              selectedEpisodeIndex: 20,
            ),
          ],
          initialEpisodeIndex: 20,
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

    expect(find.text('第21集'), findsOneWidget);
    _focusNodeForMenuLabel(tester, '第21集').requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(find.text('第21集'), findsNothing);
    expect(find.text('第20集'), findsOneWidget);
    expect(_focusNodeForMenuLabel(tester, '第20集').hasFocus, isTrue);
  });

  testWidgets(
      'play list primary up then left moves current episode 21 to episode 20',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            index: 21,
            totalEpisodes: 45,
          ),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 45,
            selectedEpisodeIndex: 20,
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeCount: 45,
              selectedEpisodeIndex: 20,
            ),
          ],
          initialEpisodeIndex: 20,
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

    _focusNodeForMenuLabel(tester, '播放列表').requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(_focusNodeForMenuLabel(tester, '第21集').hasFocus, isTrue);
    expect(_focusNodeForMenuLabel(tester, '21-40').hasFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(find.text('第21集'), findsNothing);
    expect(find.text('第20集'), findsOneWidget);
    expect(_focusNodeForMenuLabel(tester, '第20集').hasFocus, isTrue);
    expect(_focusNodeForMenuLabel(tester, '01-20').hasFocus, isFalse);
  });

  testWidgets('fullscreen player menu shell and buttons use compact sizing',
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

    final menuContainer = tester.widget<Container>(
      find.byKey(const ValueKey('tv-fullscreen-menu')),
    );
    final menuDecoration = menuContainer.decoration! as BoxDecoration;
    final menuGradient = menuDecoration.gradient! as LinearGradient;
    expect(menuGradient.colors[0].a, moreOrLessEquals(0.72));
    expect(menuGradient.colors[1].a, moreOrLessEquals(0.78));

    final primaryButton = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('播放列表'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final primaryConstraints = primaryButton.constraints!;
    expect(primaryConstraints.minWidth, 67);
    expect(primaryConstraints.maxWidth, 147);

    final secondaryButton = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('第1集'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final secondaryConstraints = secondaryButton.constraints!;
    expect(secondaryConstraints.minWidth,
        closeTo((190 * 2 / 3).ceilToDouble(), 0.1));
    expect(
      secondaryConstraints.maxWidth,
      greaterThanOrEqualTo((190 * 2 / 3).ceilToDouble()),
    );
    expect(secondaryConstraints.minHeight, greaterThanOrEqualTo(104 * 2 / 3));
  });

  testWidgets('fullscreen simple secondary menus use taller button height',
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

    const expectedHeight = 56 * 2 / 3 * 4 / 3;

    _focusNodeForMenuLabel(tester, '画面比例').requestFocus();
    await tester.pumpAndSettle();
    final fitButton = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('适应'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(fitButton.constraints!.minHeight, closeTo(expectedHeight, 0.1));

    _focusNodeForMenuLabel(tester, '倍速').requestFocus();
    await tester.pumpAndSettle();
    final speedButton = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('1.0x'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(speedButton.constraints!.minHeight, closeTo(expectedHeight, 0.1));

    _focusNodeForMenuLabel(tester, '其它').requestFocus();
    await tester.pumpAndSettle();
    final otherButton = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text('片头 00:00'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(otherButton.constraints!.minHeight, closeTo(expectedHeight, 0.1));
  });

  testWidgets('fullscreen episode cards widen with longer titles',
      (tester) async {
    const shortEpisodeTitle = '第1集';
    const longEpisodeTitle = '20260328乘风亲友连麦大会第1期';
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeTitles: [
              shortEpisodeTitle,
              longEpisodeTitle,
              '第20260518期发布会',
            ],
          ),
          sources: [
            _searchResult(
              'source_a',
              '主线路',
              episodeTitles: [
                shortEpisodeTitle,
                longEpisodeTitle,
                '第20260518期发布会',
              ],
            ),
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

    final titleWidget = tester.widget<Text>(find.text(longEpisodeTitle));
    expect(titleWidget.maxLines, 4);
    expect(titleWidget.overflow, TextOverflow.clip);

    final shortButtonFinder = find
        .ancestor(
          of: find.text(shortEpisodeTitle),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final shortEpisodeButton =
        tester.widget<AnimatedContainer>(shortButtonFinder);

    final longButtonFinder = find
        .ancestor(
          of: find.text(longEpisodeTitle),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final longEpisodeButton =
        tester.widget<AnimatedContainer>(longButtonFinder);

    expect(
      longEpisodeButton.constraints!.minWidth,
      greaterThan(shortEpisodeButton.constraints!.minWidth),
    );
    expect(
      longEpisodeButton.constraints!.maxWidth,
      greaterThan(shortEpisodeButton.constraints!.maxWidth),
    );
    expect(
      longEpisodeButton.constraints!.minHeight,
      greaterThanOrEqualTo(104 * 2 / 3),
    );
    expect(longEpisodeButton.constraints!.minHeight, lessThan(104));

    final buttonRect = tester.getRect(longButtonFinder);
    final textRect = tester.getRect(find.text(longEpisodeTitle));
    expect(
      buttonRect.inflate(0.5).contains(textRect.topLeft),
      isTrue,
    );
    expect(
      buttonRect.inflate(0.5).contains(textRect.bottomRight),
      isTrue,
    );
  });

  testWidgets('fullscreen source cards show source name and count in big card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 77),
          currentDetail: _searchResult(
            'source_a',
            '晋江超长线路资源',
            episodeCount: 77,
          ),
          sources: [
            _searchResult(
              'source_a',
              '晋江超长线路资源',
              episodeCount: 77,
            ),
            _searchResult(
              'source_b',
              '备用高清线路',
              episodeCount: 64,
            ),
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
    _focusNodeForMenuLabel(tester, '播放线路').requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('晋江超长线路资源'), findsOneWidget);
    expect(find.text('（77）'), findsOneWidget);

    final sourceButtonFinder = find
        .ancestor(
          of: find.text('晋江超长线路资源'),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final sourceButton = tester.widget<AnimatedContainer>(sourceButtonFinder);
    expect(sourceButton.constraints!.minWidth, closeTo(190 * 2 / 3, 0.1));
    expect(sourceButton.constraints!.maxWidth, closeTo(260 * 2 / 3, 0.1));
    expect(sourceButton.constraints!.minHeight, closeTo(88 * 2 / 3, 0.1));

    final buttonRect = tester.getRect(sourceButtonFinder);
    final nameRect = tester.getRect(find.text('晋江超长线路资源'));
    final countRect = tester.getRect(find.text('（77）'));
    expect(buttonRect.inflate(0.5).contains(nameRect.topLeft), isTrue);
    expect(buttonRect.inflate(0.5).contains(nameRect.bottomRight), isTrue);
    expect(buttonRect.inflate(0.5).contains(countRect.topLeft), isTrue);
    expect(buttonRect.inflate(0.5).contains(countRect.bottomRight), isTrue);
  });

  testWidgets('fullscreen source episode and group scale on focus',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 45),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 45,
          ),
          sources: [
            _searchResult('source_a', '主线路', episodeCount: 45),
            _searchResult('source_b', '备用线路', episodeCount: 45),
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

    _focusNodeForMenuLabel(tester, '播放线路').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForMenuLabel(tester, '主线路').requestFocus();
    await tester.pumpAndSettle();
    expect(_focusScaleForText(tester, '主线路'), TvVideoCard.focusedScale);

    _focusNodeForMenuLabel(tester, '播放列表').requestFocus();
    await tester.pumpAndSettle();
    _focusNodeForMenuLabel(tester, '第1集').requestFocus();
    await tester.pumpAndSettle();
    expect(_focusScaleForText(tester, '第1集'), TvVideoCard.focusedScale);

    _focusNodeForMenuLabel(tester, '01-20').requestFocus();
    await tester.pumpAndSettle();
    expect(_focusScaleForText(tester, '01-20'), TvVideoCard.focusedScale);
  });

  testWidgets('primary menu shakes at left boundary', (tester) async {
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

    _focusNodeForMenuLabel(tester, '播放列表').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(TvEdgeShake), findsWidgets);
    expect(find.byKey(const ValueKey('tv-edge-shake')), findsWidgets);
    expect(_focusNodeForMenuLabel(tester, '播放列表').hasFocus, isTrue);
  });

  testWidgets('episode row shakes at left boundary', (tester) async {
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

    _focusNodeForMenuLabel(tester, '第1集').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const ValueKey('tv-edge-shake')), findsWidgets);
    expect(_focusNodeForMenuLabel(tester, '第1集').hasFocus, isTrue);
  });

  testWidgets('uses smaller white text in TV player bottom menu',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 45),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 45,
          ),
          sources: [
            _searchResult('source_a', '主线路', episodeCount: 45),
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

    final primaryText = tester.widget<Text>(find.text('播放列表'));
    expect(primaryText.style?.fontSize, 18);
    expect(primaryText.style?.color, Colors.white);

    final secondaryText = tester.widget<Text>(find.text('第1集'));
    expect(secondaryText.style?.fontSize, 16);
    expect(secondaryText.style?.color, Colors.white);

    final groupStyle = tester.widget<AnimatedDefaultTextStyle>(
      find
          .ancestor(
            of: find.text('01-20'),
            matching: find.byType(AnimatedDefaultTextStyle),
          )
          .first,
    );
    expect(groupStyle.style.fontSize, 17);
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

  testWidgets('other menu intro and outro actions set current position',
      (tester) async {
    await UserDataService.saveSkipIntroDuration(75);
    await UserDataService.saveSkipOutroDuration(90);
    final seekPositions = <Duration>[];
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 2),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(seconds: 88),
                  duration: const Duration(seconds: 1000),
                  onSeekTo: (position) async {
                    seekPositions.add(position);
                  },
                ),
              );
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _focusNodeForMenuLabel(tester, '其它').requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('确认/空格/Enter 设置当前时间，长按清空'), findsOneWidget);

    _focusNodeForMenuLabel(tester, '片头 01:15').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('片头 01:28'), findsOneWidget);
    expect(await UserDataService.getSkipIntroDuration(), 88);

    _focusNodeForMenuLabel(tester, '片尾 01:30').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('片尾 15:12'), findsOneWidget);
    expect(await UserDataService.getSkipOutroDuration(), 912);

    expect(seekPositions, isEmpty);
  });

  testWidgets('other menu intro and outro long press clears saved positions',
      (tester) async {
    await UserDataService.saveSkipIntroDuration(75);
    await UserDataService.saveSkipOutroDuration(90);
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(totalEpisodes: 2),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(seconds: 88),
                  duration: const Duration(seconds: 1000),
                ),
              );
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _focusNodeForMenuLabel(tester, '其它').requestFocus();
    await tester.pumpAndSettle();

    _focusNodeForMenuLabel(tester, '片头 01:15').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('片头 00:00'), findsOneWidget);
    expect(await UserDataService.getSkipIntroDuration(), 0);

    _focusNodeForMenuLabel(tester, '片尾 01:30').requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('片尾 00:00'), findsOneWidget);
    expect(await UserDataService.getSkipOutroDuration(), 0);
  });

  testWidgets('other menu shows danmaku toggle and manual match entry',
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
    _focusNodeForMenuLabel(tester, '其它').requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('弹幕 开'), findsOneWidget);
    expect(find.text('手动匹配'), findsOneWidget);
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

  testWidgets('escape pops fullscreen player when menu is hidden',
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

    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('详情页'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsNothing);
  });

  testWidgets('escape closes player menu before popping fullscreen route',
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

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsNothing);
    expect(find.byKey(const ValueKey('tv-fullscreen-player')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
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
    playback.videoController = _FakeVideoPlayerWidgetController(
      isPlaying: true,
      currentPosition: const Duration(minutes: 35, seconds: 25),
      duration: const Duration(hours: 1, minutes: 46, seconds: 59),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          initialPlaybackStarted: true,
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
          initialPlaybackStarted: true,
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
          initialPlaybackStarted: true,
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
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('tv-fullscreen-bottom-current-time-slot'),
        ),
        matching: find.text('00:17'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('tv-fullscreen-bottom-total-time-slot'),
        ),
        matching: find.text('45:28'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('按【菜单键】或【下键】'), findsOneWidget);
    expect(find.textContaining('提醒：'), findsNothing);
  });

  testWidgets(
      'loading fullscreen player shows loading overlay without pause chrome',
      (tester) async {
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(seconds: 17),
      duration: const Duration(minutes: 45, seconds: 28),
      playing: false,
      loading: true,
    );
    playback.networkSpeedText = '1.5MB/s';
    playback.videoController = _FakeVideoPlayerWidgetController(
      isPlaying: false,
      isLoading: true,
      currentPosition: const Duration(seconds: 17),
      duration: const Duration(minutes: 45, seconds: 28),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          initialPlaybackStarted: false,
          playbackController: playback,
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsOneWidget);
    final loadingOverlay = tester.widget<Container>(
      find.byKey(const ValueKey('tv-fullscreen-loading')),
    );
    expect(loadingOverlay.color, isNull);
    expect(loadingOverlay.decoration, isNull);
    expect(find.text('加载中'), findsOneWidget);
    expect(find.text('1.5MB/s'), findsOneWidget);
    expect(find.text('0KB/s'), findsNothing);
    expect(
        find.byKey(const ValueKey('tv-fullscreen-center-play')), findsNothing);
    expect(find.byKey(const ValueKey('tv-fullscreen-bottom-progress')),
        findsNothing);
  });

  testWidgets(
      'fullscreen loading overlay hides only after playback position changes',
      (tester) async {
    late _FakeVideoPlayerWidgetController controller;
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              controller = _FakeVideoPlayerWidgetController(
                isPlaying: true,
                isLoading: true,
                currentPosition: const Duration(seconds: 17),
                duration: const Duration(minutes: 45, seconds: 28),
              );
              onControllerCreated(controller);
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsOneWidget);
    expect(find.text('加载中'), findsOneWidget);
    expect(find.text('0KB/s'), findsOneWidget);
    controller.emitProgress();
    await tester.pump();

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsOneWidget);
    expect(find.text('加载中'), findsOneWidget);
    expect(find.text('0KB/s'), findsOneWidget);

    controller.currentPosition = const Duration(seconds: 18);
    controller.emitProgress();
    await tester.pump();

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsNothing);
    expect(find.text('加载中'), findsNothing);
    expect(find.text('0KB/s'), findsNothing);
    expect(
      find.byKey(const ValueKey('tv-fullscreen-center-play')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('tv-fullscreen-bottom-progress')),
      findsNothing,
    );
  });

  testWidgets(
      'fullscreen loading overlay hides after progress confirms seek recovery without play event',
      (tester) async {
    late _FakeVideoPlayerWidgetController controller;
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          initialPlaybackStarted: false,
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              controller = _FakeVideoPlayerWidgetController(
                isPlaying: false,
                isLoading: true,
                currentPosition: const Duration(minutes: 35, seconds: 25),
                duration: const Duration(hours: 1, minutes: 46, seconds: 59),
              );
              onControllerCreated(controller);
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump();

    expect(
      controller.currentPosition,
      const Duration(minutes: 35, seconds: 35),
    );
    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsOneWidget);
    expect(find.text('加载中'), findsOneWidget);
    expect(find.text('0KB/s'), findsOneWidget);
    controller.emitProgress();
    await tester.pump();

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsOneWidget);
    expect(find.text('加载中'), findsOneWidget);
    expect(find.text('0KB/s'), findsOneWidget);

    controller.currentPosition = const Duration(minutes: 35, seconds: 36);
    controller.emitProgress();
    await tester.pump();

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsNothing);
    expect(find.text('加载中'), findsNothing);
    expect(find.text('0KB/s'), findsNothing);
    expect(find.byKey(const ValueKey('tv-fullscreen-center-play')),
        findsOneWidget);
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
          initialPlaybackStarted: true,
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
    final controller = _FakeVideoPlayerWidgetController(
      isPlaying: false,
      currentPosition: const Duration(seconds: 3),
      duration: const Duration(minutes: 1),
    );
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
              controller: controller,
            );
          },
        ),
      ),
    );

    await tester.pump();
    final exception = tester.takeException();
    expect(exception, isNull);
    await tester.pump();
    await tester.pump(_FakeVideoPlayerWidgetController.loadingHoldDuration);
    await tester.pump();
    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsOneWidget);

    controller.currentPosition = const Duration(seconds: 4);
    controller.emitProgress();
    await tester.pump();

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsNothing);
    expect(find.text('加载中'), findsNothing);
    expect(
      find.byKey(const ValueKey('tv-fullscreen-center-play')),
      findsOneWidget,
    );
  });

  testWidgets('arrow key seek shows center time overlay when menu is hidden',
      (tester) async {
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(minutes: 35, seconds: 25),
      duration: const Duration(hours: 1, minutes: 46, seconds: 59),
      playing: true,
    );
    playback.videoController = _FakeVideoPlayerWidgetController(
      isPlaying: true,
      currentPosition: const Duration(minutes: 35, seconds: 25),
      duration: const Duration(hours: 1, minutes: 46, seconds: 59),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          initialPlaybackStarted: true,
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

    expect(playback.seekPositions, [const Duration(minutes: 35, seconds: 35)]);
    expect(find.byKey(const ValueKey('tv-fullscreen-seek-overlay')),
        findsOneWidget);
    expect(find.text('35:35/1:46:59'), findsOneWidget);
    expect(find.textContaining('按【菜单键】或【下键】'), findsNothing);
  });

  testWidgets('brief arrow key holds seek by ten seconds instead of long press',
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
          initialPlaybackStarted: true,
          playbackController: playback,
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(playback.seekPositions, [const Duration(minutes: 35, seconds: 35)]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(playback.seekPositions, [
      const Duration(minutes: 35, seconds: 35),
      const Duration(minutes: 35, seconds: 25),
    ]);
  });

  testWidgets(
      'long press right seek advances overlay with staged 3 second ticks at slower first phase',
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
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(TvFullscreenSeekStep.longPressStartThreshold);
    await tester.pump(const Duration(milliseconds: 100));

    expect(playback.seekPositions, [
      const Duration(minutes: 35, seconds: 28),
    ]);
    expect(find.text('35:28/1:46:59'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));

    expect(playback.seekPositions, [
      const Duration(minutes: 35, seconds: 28),
      const Duration(minutes: 35, seconds: 31),
    ]);
    expect(find.text('35:31/1:46:59'), findsOneWidget);

    await tester.pump(const Duration(microseconds: 966666));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(playback.seekPositions, hasLength(11));
    expect(
      playback.seekPositions.last,
      const Duration(minutes: 35, seconds: 58),
    );
  });

  testWidgets('long press right seek keeps 30 video seconds per real second',
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
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(TvFullscreenSeekStep.longPressStartThreshold);
    await tester.pump(const Duration(seconds: 1));
    final positionAfterOneSecond = playback.seekPositions.last;
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(
      positionAfterOneSecond,
      const Duration(minutes: 35, seconds: 55),
    );
    expect(
      playback.seekPositions.last,
      const Duration(minutes: 36, seconds: 25),
    );
    expect(
      playback.seekPositions.last.inSeconds - positionAfterOneSecond.inSeconds,
      30,
    );
  });

  testWidgets(
      'long press right seek switches to 120 video seconds per real second after 5 seconds',
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
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(TvFullscreenSeekStep.longPressStartThreshold);
    await tester.pump(const Duration(seconds: 5));
    final positionAfterFiveSeconds = playback.seekPositions.last;
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(
      positionAfterFiveSeconds,
      const Duration(minutes: 37, seconds: 55),
    );
    expect(
      playback.seekPositions.last,
      const Duration(minutes: 39, seconds: 52),
    );
    expect(
      playback.seekPositions.last.inSeconds -
          positionAfterFiveSeconds.inSeconds,
      117,
    );
  });

  testWidgets(
      'long press seek hides chrome and clears recovery loading after key up',
      (tester) async {
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(minutes: 35, seconds: 25),
      duration: const Duration(hours: 1, minutes: 46, seconds: 59),
      playing: true,
    );
    playback.videoController = _FakeVideoPlayerWidgetController(
      isPlaying: true,
      currentPosition: const Duration(minutes: 35, seconds: 25),
      duration: const Duration(hours: 1, minutes: 46, seconds: 59),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          initialPlaybackStarted: true,
          playbackController: playback,
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(TvFullscreenSeekStep.longPressStartThreshold);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('tv-fullscreen-seek-overlay')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('tv-fullscreen-bottom-progress')),
        findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(
        find.byKey(const ValueKey('tv-fullscreen-seek-overlay')), findsNothing);
    expect(find.byKey(const ValueKey('tv-fullscreen-bottom-progress')),
        findsNothing);
    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 180));

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsOneWidget);
  });

  testWidgets(
      'long press seek clears recovery loading when reused controller keeps stale loading',
      (tester) async {
    final videoController = _FakeVideoPlayerWidgetController(
      isPlaying: true,
      isLoading: true,
      currentPosition: const Duration(minutes: 35, seconds: 25),
      duration: const Duration(hours: 1, minutes: 46, seconds: 59),
    );
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(minutes: 35, seconds: 25),
      duration: const Duration(hours: 1, minutes: 46, seconds: 59),
      playing: true,
      loading: true,
    )..videoController = videoController;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          initialPlaybackStarted: true,
          playbackController: playback,
          reuseExistingPlayer: true,
          playerBuilder: (_, __) => const ColoredBox(
            key: ValueKey('tv-fullscreen-player-placeholder'),
            color: Colors.black,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(TvFullscreenSeekStep.longPressStartThreshold);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 180));

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsOneWidget);

    playback.position = const Duration(minutes: 35, seconds: 36);
    videoController.currentPosition = const Duration(minutes: 35, seconds: 36);
    videoController.emitProgress();
    await tester.pump();

    expect(find.byKey(const ValueKey('tv-fullscreen-loading')), findsNothing);
  });

  testWidgets('global remote keys drive fullscreen chrome without root focus',
      (tester) async {
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(minutes: 35, seconds: 25),
      duration: const Duration(hours: 1, minutes: 46, seconds: 59),
      playing: true,
    );
    final outsideFocusNode = FocusNode();
    addTearDown(outsideFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            TvFullscreenPlayerScreen(
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
            Focus(
              focusNode: outsideFocusNode,
              child: const SizedBox(
                key: ValueKey('outside-focus-target'),
                width: 1,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();
    outsideFocusNode.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(playback.seekPositions, [const Duration(minutes: 35, seconds: 35)]);
    expect(find.byKey(const ValueKey('tv-fullscreen-seek-overlay')),
        findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tv-fullscreen-menu')), findsOneWidget);
  });

  testWidgets('center seek overlay uses reference compact width',
      (tester) async {
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(minutes: 9, seconds: 46),
      duration: const Duration(minutes: 59, seconds: 11),
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

    final overlaySize = tester.getSize(
      find.byKey(const ValueKey('tv-fullscreen-seek-overlay')),
    );
    expect(overlaySize.width, 232);
  });

  testWidgets('bottom progress track keeps leading edge stable while seeking',
      (tester) async {
    final playback = _FakeTvFullscreenPlaybackController(
      position: const Duration(minutes: 9, seconds: 59),
      duration: const Duration(minutes: 46, seconds: 9),
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

    final firstTrackRect = tester.getRect(
      find.byKey(const ValueKey('tv-fullscreen-bottom-progress')),
    );
    final firstCurrentTimeRect = tester.getRect(
      find.byKey(const ValueKey('tv-fullscreen-bottom-current-time-slot')),
    );
    expect(find.text('10:09'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    final secondTrackRect = tester.getRect(
      find.byKey(const ValueKey('tv-fullscreen-bottom-progress')),
    );
    final secondCurrentTimeRect = tester.getRect(
      find.byKey(const ValueKey('tv-fullscreen-bottom-current-time-slot')),
    );
    expect(find.text('10:19'), findsOneWidget);
    expect(
      secondCurrentTimeRect.width,
      moreOrLessEquals(firstCurrentTimeRect.width, epsilon: 0.01),
    );
    expect(
      secondTrackRect.left,
      moreOrLessEquals(firstTrackRect.left, epsilon: 0.01),
    );
    expect(
      secondTrackRect.width,
      moreOrLessEquals(firstTrackRect.width, epsilon: 0.01),
    );
  });

  testWidgets('starts fullscreen player from injected initial position',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    Duration? startPosition;
    final startPositions = <Duration?>[];
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          initialPlaybackPosition: const Duration(minutes: 9, seconds: 51),
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: Duration.zero,
                  duration: const Duration(minutes: 59, seconds: 11),
                  onUpdateDataSource: (_, {startAt, headers}) async {
                    startPositions.add(startAt);
                    startPosition = startAt;
                  },
                ),
              );
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(startPositions, [const Duration(minutes: 9, seconds: 51)]);
    expect(startPosition, const Duration(minutes: 9, seconds: 51));
  });

  testWidgets(
      'fullscreen progress listener saves record and clears old sources',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await UserDataService.saveIsLocalMode(true);
    addTearDown(() async => UserDataService.saveIsLocalMode(false));
    await LocalModeStorageService.savePlayRecord(
      PlayRecord(
        id: 'detail_source_b',
        source: 'source_b',
        title: '主角',
        sourceName: '备用线路',
        year: '2026',
        cover: '',
        index: 2,
        totalEpisodes: 2,
        playTime: 66,
        totalTime: 1000,
        saveTime: 1,
        searchTitle: '主角',
      ),
    );
    await LocalModeStorageService.savePlayRecord(
      PlayRecord(
        id: 'other_video',
        source: 'source_x',
        title: '其它影片',
        sourceName: '其它线路',
        year: '2026',
        cover: '',
        index: 3,
        totalEpisodes: 10,
        playTime: 222,
        totalTime: 800,
        saveTime: 2,
        searchTitle: '其它影片',
      ),
    );

    late _FakeVideoPlayerWidgetController controller;
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            id: 'detail_source_a',
            index: 2,
            totalEpisodes: 2,
            playTime: 30,
            totalTime: 1000,
          ),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
          ],
          initialEpisodeIndex: 1,
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              controller = _FakeVideoPlayerWidgetController(
                isPlaying: true,
                currentPosition: const Duration(seconds: 88),
                duration: const Duration(seconds: 1000),
              );
              onControllerCreated(controller);
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pump();
    controller.emitProgress();
    await tester.pump();

    final records = await LocalModeStorageService.getPlayRecords();
    expect(records.where((record) => record.title == '主角'), hasLength(1));
    expect(records.where((record) => record.source == 'source_b'), isEmpty);
    expect(
      records.where((record) => record.title == '其它影片'),
      hasLength(1),
    );
    final savedRecord =
        records.firstWhere((record) => record.source == 'source_a');
    expect(savedRecord.id, 'detail_source_a');
    expect(savedRecord.index, 2);
    expect(savedRecord.playTime, 88);
  });

  testWidgets('escape pops fullscreen player and saves progress immediately',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await UserDataService.saveIsLocalMode(true);
    addTearDown(() async => UserDataService.saveIsLocalMode(false));

    var controllerCreated = false;

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
                        videoInfo: _videoInfo(
                          id: 'detail_source_a',
                          index: 2,
                          totalEpisodes: 2,
                          playTime: 30,
                          totalTime: 1000,
                        ),
                        currentDetail: _searchResult('source_a', '主线路'),
                        sources: [
                          _searchResult('source_a', '主线路'),
                        ],
                        initialEpisodeIndex: 1,
                        playerBuilder: (_, onControllerCreated) {
                          if (!controllerCreated) {
                            controllerCreated = true;
                            onControllerCreated(
                              _FakeVideoPlayerWidgetController(
                                isPlaying: true,
                                currentPosition: const Duration(seconds: 144),
                                duration: const Duration(seconds: 1000),
                              ),
                            );
                          }
                          return const ColoredBox(
                            key: ValueKey('tv-fullscreen-player-placeholder'),
                            color: Colors.black,
                          );
                        },
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

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final records = await LocalModeStorageService.getPlayRecords();
    expect(records, hasLength(1));
    expect(records.first.source, 'source_a');
    expect(records.first.id, 'detail_source_a');
    expect(records.first.index, 2);
    expect(records.first.playTime, 144);
  });

  testWidgets('fullscreen source switch migrates play record safely',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await UserDataService.saveIsLocalMode(true);
    addTearDown(() async => UserDataService.saveIsLocalMode(false));
    await LocalModeStorageService.savePlayRecord(
      PlayRecord(
        id: 'detail_source_a',
        source: 'source_a',
        title: '主角',
        sourceName: '主线路',
        year: '2026',
        cover: '',
        index: 2,
        totalEpisodes: 2,
        playTime: 30,
        totalTime: 1000,
        saveTime: 1,
        searchTitle: '主角',
      ),
    );
    await LocalModeStorageService.savePlayRecord(
      PlayRecord(
        id: 'other_video',
        source: 'source_x',
        title: '其它影片',
        sourceName: '其它线路',
        year: '2026',
        cover: '',
        index: 3,
        totalEpisodes: 10,
        playTime: 222,
        totalTime: 800,
        saveTime: 2,
        searchTitle: '其它影片',
      ),
    );
    final startPositions = <Duration?>[];
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            id: 'detail_source_a',
            index: 2,
            totalEpisodes: 2,
            playTime: 30,
            totalTime: 1000,
          ),
          currentDetail: _searchResult('source_a', '主线路'),
          sources: [
            _searchResult('source_a', '主线路'),
            _searchResult('source_b', '备用线路'),
          ],
          initialEpisodeIndex: 1,
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(seconds: 90),
                  duration: const Duration(seconds: 1000),
                  onUpdateDataSource: (_, {startAt, headers}) async {
                    startPositions.add(startAt);
                  },
                ),
              );
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _focusNodeForMenuLabel(tester, '播放线路').requestFocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('备用线路'));
    await tester.pumpAndSettle();

    expect(startPositions, isNotEmpty);
    expect(startPositions.last, const Duration(seconds: 90));

    final records = await LocalModeStorageService.getPlayRecords();
    expect(records.where((record) => record.source == 'source_a'), isEmpty);
    expect(
        records.where((record) => record.source == 'source_b'), hasLength(1));
    final switchedRecord =
        records.firstWhere((record) => record.source == 'source_b');
    expect(switchedRecord.id, 'detail_source_b');
    expect(switchedRecord.index, 2);
    expect(switchedRecord.playTime, 90);
    expect(
      records.where((record) => record.title == '其它影片'),
      hasLength(1),
    );
  });

  testWidgets('initial playback position seeks after source update fallback',
      (tester) async {
    final seekPositions = <Duration>[];
    Duration? startPosition;
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            id: 'detail_source_a',
            index: 2,
            totalEpisodes: 3,
            playTime: 88,
            totalTime: 1000,
          ),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 3,
          ),
          sources: [
            _searchResult('source_a', '主线路', episodeCount: 3),
          ],
          initialEpisodeIndex: 1,
          initialPlaybackPosition: const Duration(seconds: 88),
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: Duration.zero,
                  duration: const Duration(seconds: 1000),
                  onUpdateDataSource: (_, {startAt, headers}) async {
                    startPosition = startAt;
                  },
                  onSeekTo: (position) async {
                    seekPositions.add(position);
                  },
                ),
              );
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(startPosition, const Duration(seconds: 88));
    expect(seekPositions, [const Duration(seconds: 88)]);
  });

  testWidgets(
      'initial playback position retries seek when first seek is ignored before progress',
      (tester) async {
    final seekPositions = <Duration>[];
    Duration? startPosition;
    late _FakeVideoPlayerWidgetController controller;
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: _videoInfo(
            id: 'detail_source_a',
            index: 2,
            totalEpisodes: 3,
            playTime: 88,
            totalTime: 1000,
          ),
          currentDetail: _searchResult(
            'source_a',
            '主线路',
            episodeCount: 3,
          ),
          sources: [
            _searchResult('source_a', '主线路', episodeCount: 3),
          ],
          initialEpisodeIndex: 1,
          initialPlaybackPosition: const Duration(seconds: 88),
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              controller = _FakeVideoPlayerWidgetController(
                isPlaying: true,
                currentPosition: Duration.zero,
                duration: const Duration(seconds: 1000),
                onUpdateDataSource: (_, {startAt, headers}) async {
                  startPosition = startAt;
                },
                onSeekTo: (position) async {
                  seekPositions.add(position);
                },
              );
              onControllerCreated(controller);
            }
            return const ColoredBox(
              key: ValueKey('tv-fullscreen-player-placeholder'),
              color: Colors.black,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(startPosition, const Duration(seconds: 88));
    expect(seekPositions, [const Duration(seconds: 88)]);

    // 模拟低端 Android 播放器吞掉 ready 前 seek，真实进度事件仍从 0 秒回来。
    controller.currentPosition = Duration.zero;
    controller.emitProgress();
    await tester.pump();

    expect(seekPositions, [
      const Duration(seconds: 88),
      const Duration(seconds: 88),
    ]);
  });

  test('TV fullscreen seek long press uses staged ticks at 30x and 120x rates',
      () {
    expect(TvFullscreenSeekStep.initialPressSeconds, 10);
    expect(
      TvFullscreenSeekStep.longPressStartThreshold,
      const Duration(milliseconds: 250),
    );
    expect(TvFullscreenSeekStep.repeatStepForElapsed(Duration.zero), 3);
    expect(
      TvFullscreenSeekStep.repeatStepForElapsed(
        const Duration(milliseconds: 4900),
      ),
      3,
    );
    expect(
      TvFullscreenSeekStep.repeatStepForElapsed(const Duration(seconds: 5)),
      3,
    );
    expect(
      TvFullscreenSeekStep.repeatStepForElapsed(const Duration(seconds: 6)),
      6,
    );
    expect(
      TvFullscreenSeekStep.repeatStepForElapsed(
        const Duration(milliseconds: 6050),
      ),
      6,
    );
    expect(
      TvFullscreenSeekStep.repeatStepForElapsed(
        const Duration(milliseconds: 7500),
      ),
      6,
    );
    expect(
      TvFullscreenSeekStep.repeatIntervalMicrosecondsForElapsed(Duration.zero),
      16667,
    );
    expect(
      TvFullscreenSeekStep.repeatIntervalMicrosecondsForElapsed(
        const Duration(seconds: 5),
      ),
      16667,
    );
    expect(
      TvFullscreenSeekStep.repeatIntervalMicrosecondsForElapsed(
        const Duration(milliseconds: 6050),
      ),
      8333,
    );
    expect(
      TvFullscreenSeekStep.totalSeekSecondsForElapsed(
          const Duration(seconds: 1)),
      30,
    );
    expect(
      TvFullscreenSeekStep.totalSeekSecondsForElapsed(
          const Duration(seconds: 5)),
      150,
    );
    expect(
      TvFullscreenSeekStep.totalSeekSecondsForElapsed(
          const Duration(seconds: 6)),
      270,
    );
    expect(
      TvFullscreenSeekStep.elapsedMicrosecondsForTotalSeekSeconds(30),
      1000000,
    );
    expect(
      TvFullscreenSeekStep.elapsedMicrosecondsForTotalSeekSeconds(150),
      5000000,
    );
    expect(
      TvFullscreenSeekStep.elapsedMicrosecondsForTotalSeekSeconds(270),
      6000000,
    );
  });
}

FocusNode _focusNodeForMenuLabel(WidgetTester tester, String label) {
  final focusFinder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) {
        if (widget is! Focus || widget.focusNode == null) {
          return false;
        }
        final debugLabel = widget.focusNode!.debugLabel ?? '';
        return debugLabel.startsWith('tv-player-menu-') ||
            debugLabel.startsWith('tv-player-secondary-') ||
            debugLabel.startsWith('tv-fullscreen-episode-group-');
      },
    ),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
}

double _focusScaleForText(WidgetTester tester, String text) {
  final scaleFinder = find.ancestor(
    of: find.text(text),
    matching: find.byType(AnimatedScale),
  );
  return tester.widget<AnimatedScale>(scaleFinder.first).scale;
}

Rect _menuButtonRect(WidgetTester tester, String label) {
  final buttonFinder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is AnimatedContainer),
  );
  return tester.getRect(buttonFinder.first);
}

String _nearestMenuLabelByHorizontalCenter(
  WidgetTester tester, {
  required String anchorLabel,
  required List<String> candidateLabels,
}) {
  final anchorCenter = _menuLabelRect(tester, anchorLabel).center.dx;
  var nearestLabel = '';
  var nearestDistance = double.infinity;
  for (final label in candidateLabels) {
    final finder = find.text(label);
    if (finder.evaluate().isEmpty) {
      continue;
    }
    final distance =
        (_menuLabelRect(tester, label).center.dx - anchorCenter).abs();
    if (distance < nearestDistance) {
      nearestLabel = label;
      nearestDistance = distance;
    }
  }
  expect(nearestLabel, isNotEmpty);
  return nearestLabel;
}

String? _focusedMenuLabelIn(WidgetTester tester, List<String> labels) {
  for (final label in labels) {
    final finder = find.text(label);
    if (finder.evaluate().isEmpty) {
      continue;
    }
    if (_focusNodeForMenuLabel(tester, label).hasFocus) {
      return label;
    }
  }
  return null;
}

Rect _menuLabelRect(WidgetTester tester, String label) {
  final buttonFinder = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is AnimatedContainer),
  );
  if (buttonFinder.evaluate().isNotEmpty) {
    return tester.getRect(buttonFinder.first);
  }
  return tester.getRect(find.text(label).first);
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

void _expectMenuButtonNearListLeadingEdge(
  WidgetTester tester, {
  required String listKey,
  required Finder itemFinder,
  double maxLeadingGap = 36,
}) {
  final buttonFinder = find.ancestor(
    of: itemFinder,
    matching: find.byWidgetPredicate((widget) => widget is AnimatedContainer),
  );
  final listRect = tester.getRect(find.byKey(ValueKey(listKey)));
  final itemRect = tester.getRect(buttonFinder.first);
  expect(itemRect.left - listRect.left, lessThanOrEqualTo(maxLeadingGap));
}

VideoInfo _videoInfo({
  String id = 'main',
  int index = 1,
  int totalEpisodes = 2,
  int playTime = 0,
  int totalTime = 0,
}) {
  return VideoInfo(
    id: id,
    source: 'source_a',
    title: '主角',
    sourceName: '主线路',
    year: '2026',
    cover: '',
    index: index,
    totalEpisodes: totalEpisodes,
    playTime: playTime,
    totalTime: totalTime,
    saveTime: 0,
    searchTitle: '主角',
  );
}

SearchResult _searchResult(
  String source,
  String sourceName, {
  int episodeCount = 2,
  int selectedEpisodeIndex = 0,
  List<String>? episodeTitles,
}) {
  final episodes = List<String>.generate(
    episodeTitles?.length ?? episodeCount,
    (index) => 'https://example.com/${index + 1}.m3u8',
  );
  final titles = episodeTitles ??
      List<String>.generate(
        episodeCount,
        (index) => '第${index + 1}集',
      );
  return SearchResult(
    id: 'detail_$source',
    title: '主角',
    poster: '',
    episodes: episodes,
    episodesTitles: titles,
    source: source,
    sourceName: sourceName,
    year: '2026',
    desc: '这是一段详情介绍。',
  );
}

class _FakeTvFullscreenPlaybackController
    implements
        TvFullscreenPlaybackController,
        TvFullscreenVideoControllerProvider {
  _FakeTvFullscreenPlaybackController({
    required this.position,
    required this.duration,
    required this.playing,
    this.loading = false,
  });

  Duration position;
  Duration duration;
  bool playing;
  bool loading;
  @override
  String networkSpeedText = '0KB/s';
  @override
  VideoPlayerWidgetController? videoController;
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
  bool get isLoading => loading;

  @override
  void addNetworkSpeedListener(VoidCallback listener) {}

  @override
  void removeNetworkSpeedListener(VoidCallback listener) {}

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
    this.isLoading = false,
    this.onUpdateDataSource,
    this.onSeekTo,
  });

  static const Duration loadingHoldDuration = Duration(milliseconds: 520);

  @override
  final bool isPlaying;

  @override
  Duration? currentPosition;

  @override
  final Duration? duration;

  @override
  bool isLoading;

  @override
  String networkSpeedText = '0KB/s';

  final List<VoidCallback> _progressListeners = [];
  final List<VoidCallback> _networkSpeedListeners = [];

  final Future<void> Function(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  })? onUpdateDataSource;

  final Future<void> Function(Duration position)? onSeekTo;

  @override
  void addProgressListener(VoidCallback listener) {
    if (!_progressListeners.contains(listener)) {
      _progressListeners.add(listener);
    }
  }

  @override
  void addNetworkSpeedListener(VoidCallback listener) {
    if (!_networkSpeedListeners.contains(listener)) {
      _networkSpeedListeners.add(listener);
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
  void removeNetworkSpeedListener(VoidCallback listener) {
    _networkSpeedListeners.remove(listener);
  }

  @override
  Future<void> seekTo(Duration position) async {
    currentPosition = position;
    await onSeekTo?.call(position);
  }

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

class _SynchronousControllerCreatedProbe extends StatefulWidget {
  const _SynchronousControllerCreatedProbe({
    required this.onControllerCreated,
    this.controller,
  });

  final void Function(VideoPlayerWidgetController controller)
      onControllerCreated;
  final _FakeVideoPlayerWidgetController? controller;

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
      widget.controller ??
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
