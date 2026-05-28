import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/services/tv_search_recommend_service.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TvSearchRecommendService.clearDebugCache();
  });

  tearDown(() {
    TvSearchRecommendService.clearDebugCache();
  });

  testWidgets('stores at most two latest detail recommend groups',
      (tester) async {
    final groupA = [
      _videoInfo('a_1', 'A1'),
      _videoInfo('a_2', 'A2'),
    ];
    final groupB = [
      _videoInfo('b_1', 'B1'),
    ];
    final groupC = [
      _videoInfo('c_1', 'C1'),
    ];

    TvSearchRecommendService.recordDetailRecommends(
      videoInfo: _videoInfo('detail_a', '详情 A'),
      recommends: groupA,
    );
    TvSearchRecommendService.recordDetailRecommends(
      videoInfo: _videoInfo('detail_b', '详情 B'),
      recommends: groupB,
    );
    TvSearchRecommendService.recordDetailRecommends(
      videoInfo: _videoInfo('detail_c', '详情 C'),
      recommends: groupC,
    );

    final merged = await TvSearchRecommendService.loadSearchRecommends(
      fallbackLoader: () async => const <VideoInfo>[],
    );

    expect(
      merged.map((video) => video.title).toList(),
      ['C1', 'B1'],
    );
  });

  testWidgets('new detail group moves to top and replaces oldest group',
      (tester) async {
    final groupA = [
      _videoInfo('shared', '共享影片'),
      _videoInfo('a_2', 'A2'),
    ];
    final groupB = [
      _videoInfo('b_1', 'B1'),
      _videoInfo('shared_2', '共享影片'),
    ];

    TvSearchRecommendService.recordDetailRecommends(
      videoInfo: _videoInfo('detail_a', '详情 A'),
      recommends: groupA,
    );
    TvSearchRecommendService.recordDetailRecommends(
      videoInfo: _videoInfo('detail_b', '详情 B'),
      recommends: groupB,
    );

    final merged = await TvSearchRecommendService.loadSearchRecommends(
      fallbackLoader: () async => const <VideoInfo>[],
    );

    expect(
      merged.map((video) => video.title).toList(),
      ['B1', '共享影片', 'A2'],
    );
  });

  testWidgets('falls back to latest hot tv and show entries when no detail cache',
      (tester) async {
    final fallback = [
      ...List<VideoInfo>.generate(
        10,
        (index) => _videoInfo('tv_$index', '剧集$index'),
      ),
      ...List<VideoInfo>.generate(
        10,
        (index) => _videoInfo('show_$index', '综艺$index'),
      ),
    ];

    final merged = await TvSearchRecommendService.loadSearchRecommends(
      fallbackLoader: () async => fallback,
    );

    expect(merged, hasLength(20));
    expect(merged.first.title, '剧集0');
    expect(merged[9].title, '剧集9');
    expect(merged[10].title, '综艺0');
    expect(merged.last.title, '综艺9');
  });
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
