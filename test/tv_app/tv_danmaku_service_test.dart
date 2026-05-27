import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/danmaku_service.dart';
import 'package:selene/tv_app/services/tv_danmaku_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('builds TV danmaku match file names with title and parsed episode', () {
    final candidates = TvDanmakuService.buildMatchFileNames(
      videoTitle: '进击的巨人',
      sourceName: '主线路',
      episodeIndex: 1,
      episodeTitle: '第12集',
    );

    expect(
      candidates,
      [
        DanmakuService.buildFileName('进击的巨人', 1, '主线路'),
        DanmakuService.buildFileName('进击的巨人 第12集', null, '主线路'),
        DanmakuService.buildFileName('进击的巨人', 11, '主线路'),
      ],
    );
  });

  test('resolves TV initial manual match query with exact cache first', () async {
    final baseService = DanmakuService();
    await baseService.saveLastManualMatchQueryForTitle('海贼王', 'one piece');
    await baseService.saveManualMatchQuery(
      'source_a',
      'video_1',
      2,
      '海贼王 和之国',
    );

    final service = TvDanmakuService(baseService: baseService);
    final query = await service.resolveInitialMatchQuery(
      currentSource: 'source_a',
      currentId: 'video_1',
      episodeIndex: 2,
      fallbackTitle: '海贼王',
      videoTitle: '海贼王',
    );

    expect(query, '海贼王 和之国');
  });

  test('resolves TV initial manual match query with title fallback', () async {
    final baseService = DanmakuService();
    await baseService.saveLastManualMatchQueryForTitle('银魂', 'gintama');

    final service = TvDanmakuService(baseService: baseService);
    final query = await service.resolveInitialMatchQuery(
      currentSource: '',
      currentId: '',
      episodeIndex: 0,
      fallbackTitle: '银魂',
      videoTitle: '银魂',
    );

    expect(query, 'gintama');
  });
}
