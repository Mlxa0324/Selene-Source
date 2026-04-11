import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:selene/services/danmaku_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('保存手动匹配时同时缓存剧集和搜索词', () async {
    final service = DanmakuService();

    await service.saveManualMatch(
      'test_source',
      'video_1',
      3,
      9527,
      searchKeyword: '海贼王',
    );

    expect(
      await service.getManualMatch('test_source', 'video_1', 3),
      9527,
    );
    expect(
      await service.getManualMatchQuery('test_source', 'video_1', 3),
      '海贼王',
    );
  });

  test('兼容旧格式手动匹配缓存', () async {
    SharedPreferences.setMockInitialValues({
      'danmaku_manual_matches': jsonEncode({
        'legacy_source_legacy_id_1': 42,
      }),
    });

    final service = DanmakuService();

    expect(
      await service.getManualMatch('legacy_source', 'legacy_id', 1),
      42,
    );
    expect(
      await service.getManualMatchQuery('legacy_source', 'legacy_id', 1),
      isNull,
    );
  });

  test('单独缓存搜索词时允许没有剧集ID', () async {
    final service = DanmakuService();

    await service.saveManualMatchQuery(
      'test_source',
      'video_2',
      5,
      '银魂',
    );

    expect(
      await service.getManualMatch('test_source', 'video_2', 5),
      isNull,
    );
    expect(
      await service.getManualMatchQuery('test_source', 'video_2', 5),
      '银魂',
    );
  });

  test('单独缓存搜索词时保留已有剧集ID', () async {
    final service = DanmakuService();

    await service.saveManualMatch(
      'test_source',
      'video_3',
      2,
      114514,
      searchKeyword: '旧关键词',
    );

    await service.saveManualMatchQuery(
      'test_source',
      'video_3',
      2,
      '新关键词',
    );

    expect(
      await service.getManualMatch('test_source', 'video_3', 2),
      114514,
    );
    expect(
      await service.getManualMatchQuery('test_source', 'video_3', 2),
      '新关键词',
    );
  });

  test('读取初始搜索词时会回退到同标题最近一次手动匹配搜索词', () async {
    final service = DanmakuService();

    await service.saveLastManualMatchQueryForTitle(
      '进击的巨人',
      'Attack on Titan',
    );

    expect(
      await service.resolveManualMatchQuery(
        'other_source',
        'video_4',
        9,
        fallbackTitle: '进击的巨人',
      ),
      'Attack on Titan',
    );
  });

  test('读取初始搜索词时优先返回当前源当前集的精确缓存', () async {
    final service = DanmakuService();

    await service.saveLastManualMatchQueryForTitle(
      '银魂',
      'gintama',
    );
    await service.saveManualMatchQuery(
      'test_source',
      'video_5',
      2,
      '银魂 第三季',
    );

    expect(
      await service.resolveManualMatchQuery(
        'test_source',
        'video_5',
        2,
        fallbackTitle: '银魂',
      ),
      '银魂 第三季',
    );
  });

  test('保存手动匹配条目时会把后续集映射到后续视频集并持久化', () async {
    final service = DanmakuService();

    await service.saveManualMatchSeries(
      'test_source',
      'video_variety',
      10,
      const [501, 502, 503, 504],
      selectedEpisodeOffset: 1,
      searchKeyword: '20250601期',
    );

    expect(
      await service.getManualMatch('test_source', 'video_variety', 10),
      502,
    );
    expect(
      await service.getManualMatch('test_source', 'video_variety', 11),
      503,
    );
    expect(
      await service.getManualMatch('test_source', 'video_variety', 12),
      504,
    );
    expect(
      await service.getManualMatchQuery('test_source', 'video_variety', 11),
      '20250601期',
    );
  });
}
