import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/play_record.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/services/tv_play_record_service.dart';

void main() {
  test('resolveSearchTitle matches mobile fallback semantics', () {
    final customSearchTitleVideo = VideoInfo(
      id: 'video_a',
      source: 'source_a',
      title: '影片标题',
      sourceName: '主线路',
      year: '2026',
      cover: '',
      index: 1,
      totalEpisodes: 1,
      playTime: 0,
      totalTime: 0,
      saveTime: 0,
      searchTitle: '搜索标题',
    );
    final fallbackTitleVideo = VideoInfo(
      id: 'video_b',
      source: 'source_b',
      title: '影片标题',
      sourceName: '主线路',
      year: '2026',
      cover: '',
      index: 1,
      totalEpisodes: 1,
      playTime: 0,
      totalTime: 0,
      saveTime: 0,
      searchTitle: '   ',
    );

    expect(
      TvPlayRecordService.resolveSearchTitle(customSearchTitleVideo),
      '搜索标题',
    );
    expect(
      TvPlayRecordService.resolveSearchTitle(fallbackTitleVideo),
      '影片标题',
    );
  });

  test('isSameVideoForPlayRecord only matches same title group', () {
    final keepSource = SearchResult(
      id: 'detail_source_b',
      title: '火影忍者',
      poster: '',
      episodes: const ['https://example.com/1.m3u8'],
      episodesTitles: const ['第1集'],
      source: 'source_b',
      sourceName: '备用线路',
      year: '2026',
      desc: '简介',
    );
    final sameVideoRecord = PlayRecord(
      id: 'detail_source_a',
      source: 'source_a',
      title: '火影忍者',
      sourceName: '主线路',
      year: '2026',
      cover: '',
      index: 1,
      totalEpisodes: 1,
      playTime: 66,
      totalTime: 100,
      saveTime: 1,
      searchTitle: '火影忍者',
    );
    final unrelatedRecord = PlayRecord(
      id: 'another_source',
      source: 'source_x',
      title: '海贼王',
      sourceName: '其它线路',
      year: '2026',
      cover: '',
      index: 1,
      totalEpisodes: 1,
      playTime: 88,
      totalTime: 100,
      saveTime: 2,
      searchTitle: '海贼王',
    );

    expect(
      TvPlayRecordService.isSameVideoForPlayRecord(
        record: sameVideoRecord,
        targetSource: keepSource,
        searchTitle: '火影忍者',
      ),
      isTrue,
    );
    expect(
      TvPlayRecordService.isSameVideoForPlayRecord(
        record: unrelatedRecord,
        targetSource: keepSource,
        searchTitle: '火影忍者',
      ),
      isFalse,
    );
  });
}
