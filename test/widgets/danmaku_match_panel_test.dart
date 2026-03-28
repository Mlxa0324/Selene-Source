import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/widgets/danmaku_match_panel.dart';

void main() {
  testWidgets('定位按钮会先滚动到离屏目标，再展开当前弹幕项', (tester) async {
    final result = DanmakuSearchResult(
      errorCode: 0,
      success: true,
      errorMessage: '',
      animes: List.generate(24, (animeIndex) {
        final animeId = animeIndex + 1;
        return DanmakuSearchAnime(
          animeId: animeId,
          animeTitle: animeId == 20 ? '目标作品' : '作品$animeId',
          type: 'anime',
          typeDescription: '动漫',
          year: 2000 + animeId,
          episodes: List.generate(3, (episodeIndex) {
            final episodeId = animeId * 100 + episodeIndex + 1;
            return DanmakuSearchEpisode(
              episodeId: episodeId,
              episodeTitle: animeId == 20 && episodeIndex == 1
                  ? '目标第2集'
                  : '第${episodeIndex + 1}集',
            );
          }),
        );
      }),
    );

    Future<DanmakuSearchResult?> fakeSearch(String _) async => result;

    Future<void> pumpPanel({int? currentEpisodeId}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 420,
                height: 420,
                child: DanmakuMatchPanel(
                  theme: ThemeData.dark(),
                  initialQuery: '火影忍者',
                  currentEpisodeId: currentEpisodeId,
                  currentEpisodeCommentCount:
                      currentEpisodeId == null ? null : 719,
                  onEpisodeSelected: (_, __) {},
                  searchEpisodesOverride: fakeSearch,
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pumpPanel();
    await tester.pumpAndSettle();

    final scrollView = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect(scrollView.controller?.offset ?? 0, 0);
    expect(find.text('目标第2集'), findsNothing);

    await pumpPanel(currentEpisodeId: 2002);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('定位到当前弹幕'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final updatedScrollView = tester
        .widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
    expect(updatedScrollView.controller?.offset ?? 0, greaterThan(0));
    expect(find.text('目标第2集'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  });

  testWidgets('目标分组离屏很远时，首次点击定位也能直接滚到当前弹幕', (tester) async {
    final result = DanmakuSearchResult(
      errorCode: 0,
      success: true,
      errorMessage: '',
      animes: List.generate(180, (animeIndex) {
        final animeId = animeIndex + 1;
        return DanmakuSearchAnime(
          animeId: animeId,
          animeTitle: animeId == 150 ? '很远的目标作品' : '作品$animeId',
          type: 'anime',
          typeDescription: '动漫',
          year: 2000 + animeId,
          episodes: List.generate(3, (episodeIndex) {
            final episodeId = animeId * 100 + episodeIndex + 1;
            return DanmakuSearchEpisode(
              episodeId: episodeId,
              episodeTitle: animeId == 150 && episodeIndex == 1
                  ? '很远的目标第2集'
                  : '第${episodeIndex + 1}集',
            );
          }),
        );
      }),
    );

    Future<DanmakuSearchResult?> fakeSearch(String _) async => result;

    Future<void> pumpPanel({int? currentEpisodeId}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 420,
                height: 280,
                child: DanmakuMatchPanel(
                  theme: ThemeData.dark(),
                  initialQuery: '海贼王',
                  currentEpisodeId: currentEpisodeId,
                  currentEpisodeCommentCount:
                      currentEpisodeId == null ? null : 1201,
                  onEpisodeSelected: (_, __) {},
                  searchEpisodesOverride: fakeSearch,
                ),
              ),
            ),
          ),
        ),
      );
    }

    await pumpPanel();
    await tester.pumpAndSettle();

    await pumpPanel(currentEpisodeId: 15002);
    await tester.pumpAndSettle();

    expect(find.text('很远的目标第2集'), findsNothing);

    await tester.tap(find.byTooltip('定位到当前弹幕'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('很远的目标第2集'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  });
}
