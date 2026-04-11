import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/services/danmaku_service.dart';
import 'package:selene/widgets/danmaku_match_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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
                  onEpisodeSelected: (_, __, ___, ____) {},
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
                  onEpisodeSelected: (_, __, ___, ____) {},
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

  testWidgets('点击搜索后即使没有结果也会缓存当前搜索词', (tester) async {
    final service = DanmakuService();
    const source = 'test_source';
    const id = 'video_1';
    const episodeIndex = 7;

    Future<DanmakuSearchResult?> fakeSearch(String _) async => DanmakuSearchResult(
          errorCode: 1,
          success: false,
          errorMessage: '未找到结果',
          animes: const [],
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              height: 420,
              child: DanmakuMatchPanel(
                theme: ThemeData.dark(),
                initialQuery: '',
                onEpisodeSelected: (_, __, ___, ____) {},
                onSearchSubmitted: (query) => service.saveManualMatchQuery(
                  source,
                  id,
                  episodeIndex,
                  query,
                ),
                searchEpisodesOverride: fakeSearch,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'JOJO');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(
      await service.getManualMatchQuery(source, id, episodeIndex),
      'JOJO',
    );
  });

  testWidgets('点击剧集时会把所属条目和选中位置一起回传', (tester) async {
    final result = DanmakuSearchResult(
      errorCode: 0,
      success: true,
      errorMessage: '',
      animes: [
        DanmakuSearchAnime(
          animeId: 7,
          animeTitle: '测试综艺',
          type: 'tvseries',
          typeDescription: '综艺',
          episodes: [
            DanmakuSearchEpisode(episodeId: 701, episodeTitle: '20250525期'),
            DanmakuSearchEpisode(episodeId: 702, episodeTitle: '20250601期'),
            DanmakuSearchEpisode(episodeId: 703, episodeTitle: '20250608期'),
          ],
        ),
      ],
    );

    int? selectedEpisodeId;
    int? selectedEpisodeIndex;
    DanmakuSearchAnime? selectedAnime;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 420,
            child: DanmakuMatchPanel(
              theme: ThemeData.dark(),
              initialQuery: '测试综艺',
              onEpisodeSelected: (episodeId, _, anime, episodeIndex) {
                selectedEpisodeId = episodeId;
                selectedAnime = anime;
                selectedEpisodeIndex = episodeIndex;
              },
              searchEpisodesOverride: (_) async => result,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('测试综艺').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('20250601期'));
    await tester.pumpAndSettle();

    expect(selectedEpisodeId, 702);
    expect(selectedEpisodeIndex, 1);
    expect(selectedAnime?.animeId, 7);
    expect(selectedAnime?.episodes.length, 3);
  });
}
