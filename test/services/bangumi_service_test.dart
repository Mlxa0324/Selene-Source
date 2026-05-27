import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:selene/services/bangumi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(BangumiService.resetForTest);
  tearDown(BangumiService.resetForTest);

  testWidgets('falls back to cached calendar when network request fails',
      (tester) async {
    BangumiService.skipCacheInitForTest();
    BangumiService.calendarHttpGetForTest = (uri, headers) async {
      return http.Response('', HttpStatus.serviceUnavailable);
    };
    BangumiService.calendarCacheReaderForTest = (cacheKey, allowExpired) async {
      if (!allowExpired || cacheKey != 'bangumi_calendar_raw_v1') {
        return null;
      }
      return json.decode(json.encode(_calendarPayload())) as List<dynamic>;
    };

    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    final response = await BangumiService.getCalendarByWeekday(
      tester.element(find.byType(Placeholder)),
      3,
    );

    expect(response.success, isTrue);
    expect(response.data, hasLength(1));
    expect(response.data!.single.nameCn, '周三番剧');
  });
}

List<Map<String, dynamic>> _calendarPayload() {
  return [
    {
      'weekday': {
        'en': 'Wed',
        'cn': '星期三',
        'ja': '水曜日',
        'id': 3,
      },
      'items': [
        {
          'id': 1001,
          'url': 'https://bgm.tv/subject/1001',
          'type': 2,
          'name': 'Wednesday Anime',
          'name_cn': '周三番剧',
          'summary': '测试缓存兜底',
          'air_date': '2026-05-27',
          'air_weekday': 3,
          'rating': {'score': 8.2},
          'rank': 1,
          'images': {
            'common': 'https://example.com/common.jpg',
          },
          'collection': {},
        },
      ],
    },
  ];
}
