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
}
