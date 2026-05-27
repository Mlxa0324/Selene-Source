import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_video_library_screen.dart';

void main() {
  testWidgets('escape pops TV video library page without waiting extra frame',
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
                          TvVideoLibraryScreen(
                        title: '播放历史',
                        loadVideos: (_) async => [
                          _videoInfo('history_1', '历史影片'),
                        ],
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开视频库页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开视频库页'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('打开视频库页'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tv-video-library-screen-播放历史')),
      findsNothing,
    );
  });

  testWidgets('history page clears all items from header action',
      (tester) async {
    var history = <VideoInfo>[
      _videoInfo('history_1', '历史影片 1'),
      _videoInfo('history_2', '历史影片 2'),
    ];

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
                          TvVideoLibraryScreen(
                        title: '播放历史',
                        loadVideos: (_) async => history,
                        onDeleteVideo: (_, videoInfo) async {
                          history.removeWhere(
                            (item) =>
                                item.source == videoInfo.source &&
                                item.id == videoInfo.id,
                          );
                          return true;
                        },
                        onClearVideos: (_) async {
                          history = <VideoInfo>[];
                          return true;
                        },
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开视频库页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开视频库页'));
    await tester.pumpAndSettle();

    expect(find.text('历史影片 1'), findsOneWidget);
    expect(find.text('历史影片 2'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('tv-video-library-clear-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tv-confirm-dialog')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('清空播放历史'), findsOneWidget);
    expect(find.text('确定要清空全部内容吗？'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tv-confirm-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.text('历史影片 1'), findsNothing);
    expect(find.text('历史影片 2'), findsNothing);
    expect(find.text('暂无内容'), findsOneWidget);
  });

  testWidgets('favorite card long press deletes current item', (tester) async {
    var favorites = <VideoInfo>[
      _videoInfo('favorite_1', '收藏影片 1'),
      _videoInfo('favorite_2', '收藏影片 2'),
    ];

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
                          TvVideoLibraryScreen(
                        title: '收藏夹',
                        loadVideos: (_) async => favorites,
                        onDeleteVideo: (_, videoInfo) async {
                          favorites.removeWhere(
                            (item) =>
                                item.source == videoInfo.source &&
                                item.id == videoInfo.id,
                          );
                          return true;
                        },
                        onClearVideos: (_) async {
                          favorites = <VideoInfo>[];
                          return true;
                        },
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开收藏夹页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开收藏夹页'));
    await tester.pumpAndSettle();

    final focusNode = _focusNodeForCard(tester, 'favorite_1');
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('删除当前收藏'), findsOneWidget);
    expect(find.byKey(const ValueKey('tv-confirm-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tv-confirm-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.text('收藏影片 1'), findsNothing);
    expect(find.text('收藏影片 2'), findsOneWidget);
  });
}

FocusNode _focusNodeForCard(WidgetTester tester, String id) {
  final focusFinder = find.descendant(
    of: find.byKey(ValueKey('tv-video-card-focus-$id')),
    matching: find.byWidgetPredicate((widget) {
      return widget is Focus && widget.focusNode != null;
    }),
  );
  return tester.widget<Focus>(focusFinder.first).focusNode!;
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
