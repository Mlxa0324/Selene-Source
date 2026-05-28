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

  testWidgets('falls back to proxy api before calendar page html',
      (tester) async {
    // 跳过真实缓存初始化，避免测试依赖磁盘与插件环境。
    BangumiService.skipCacheInitForTest();
    BangumiService.calendarHttpGetForTest = (uri, headers) async {
      if (uri.host == 'api.bgm.tv') {
        return http.Response('', HttpStatus.serviceUnavailable);
      }
      if (uri.host == 'pz.v88.qzz.io') {
        return http.Response.bytes(
          utf8.encode(json.encode(_proxyCalendarPayload())),
          HttpStatus.ok,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }
      return http.Response('', HttpStatus.serviceUnavailable);
    };
    BangumiService.calendarCacheReaderForTest = (cacheKey, allowExpired) async {
      return null;
    };
    BangumiService.calendarPageHtmlLoaderForTest = () async {
      fail('代理接口命中成功后不应该再进入页面兜底。');
    };

    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    final response = await BangumiService.getCalendarByWeekday(
      tester.element(find.byType(Placeholder)),
      5,
    );

    expect(response.success, isTrue);
    expect(response.data, hasLength(2));
    expect(response.data!.first.id, 910001);
    expect(response.data!.first.nameCn, '代理周五番剧');
    expect(response.data!.last.name, 'Proxy Friday Original 2');
  });

  testWidgets(
      'falls back to calendar page html when primary api, proxy api and cache all fail',
      (tester) async {
    // 跳过真实缓存初始化，避免测试依赖磁盘与插件环境。
    BangumiService.skipCacheInitForTest();
    BangumiService.calendarHttpGetForTest = (uri, headers) async {
      return http.Response('', HttpStatus.serviceUnavailable);
    };
    BangumiService.calendarCacheReaderForTest = (cacheKey, allowExpired) async {
      return null;
    };
    BangumiService.calendarPageHtmlLoaderForTest = () async {
      return _calendarHtmlPayload();
    };

    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    final response = await BangumiService.getCalendarByWeekday(
      tester.element(find.byType(Placeholder)),
      5,
    );

    expect(response.success, isTrue);
    expect(response.data, hasLength(2));
    expect(response.data!.first.id, 900001);
    expect(response.data!.first.nameCn, '测试中文标题');
    expect(response.data!.first.name, 'テスト原題');
    expect(
      response.data!.first.images.bestImageUrl,
      'https://lain.bgm.tv/r/400/pic/cover/l/aa/bb/900001_test.jpg',
    );
    expect(response.data!.last.nameCn, isNull);
    expect(response.data!.last.name, '只有原题');
  });

  testWidgets('parses whole week payload from calendar page fallback',
      (tester) async {
    // 跳过真实缓存初始化，避免测试依赖磁盘与插件环境。
    BangumiService.skipCacheInitForTest();
    BangumiService.calendarHttpGetForTest = (uri, headers) async {
      return http.Response('', HttpStatus.serviceUnavailable);
    };
    BangumiService.calendarCacheReaderForTest = (cacheKey, allowExpired) async {
      return null;
    };
    BangumiService.calendarPageHtmlLoaderForTest = () async {
      return _calendarHtmlPayload();
    };

    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    final response = await BangumiService.getCalendarByWeekday(
      tester.element(find.byType(Placeholder)),
      6,
    );

    expect(response.success, isTrue);
    expect(response.data, hasLength(1));
    expect(response.data!.single.id, 900003);
    expect(response.data!.single.nameCn, '周六番剧');
    expect(response.data!.single.name, 'Saturday Title');
  });

  testWidgets('switches to calendar page fallback after api timeout',
      (tester) async {
    // 跳过真实缓存初始化，避免测试依赖磁盘与插件环境。
    BangumiService.skipCacheInitForTest();
    BangumiService.calendarApiTimeoutForTest = const Duration(milliseconds: 10);
    BangumiService.calendarHttpGetForTest = (uri, headers) async {
      if (uri.host == 'api.bgm.tv') {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return http.Response(json.encode(_calendarPayload()), HttpStatus.ok);
      }
      return http.Response('', HttpStatus.serviceUnavailable);
    };
    BangumiService.calendarCacheReaderForTest = (cacheKey, allowExpired) async {
      return null;
    };
    BangumiService.calendarPageHtmlLoaderForTest = () async {
      return _calendarHtmlPayload();
    };

    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    final response = await tester.runAsync(
      () => BangumiService.getCalendarByWeekday(
        tester.element(find.byType(Placeholder)),
        5,
      ),
    );

    expect(response!.success, isTrue);
    expect(response.data, hasLength(2));
    expect(response.data!.first.id, 900001);
    expect(response.data!.first.nameCn, '测试中文标题');
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

List<Map<String, dynamic>> _proxyCalendarPayload() {
  return [
    {
      'weekday': {
        'en': 'Fri',
        'cn': '星期五',
        'ja': '金曜日',
        'id': 5,
      },
      'items': [
        {
          'id': 910001,
          'url': 'https://bgm.tv/subject/910001',
          'type': 2,
          'name': 'Proxy Friday Original 1',
          'name_cn': '代理周五番剧',
          'summary': '测试代理接口兜底',
          'air_date': '2026-05-29',
          'air_weekday': 5,
          'rating': {'score': 8.6},
          'rank': 2,
          'images': {
            'common': 'https://example.com/proxy-1.jpg',
          },
          'collection': {},
        },
        {
          'id': 910002,
          'url': 'https://bgm.tv/subject/910002',
          'type': 2,
          'name': 'Proxy Friday Original 2',
          'name_cn': null,
          'summary': '测试代理接口第二条',
          'air_date': '2026-05-29',
          'air_weekday': 5,
          'rating': {'score': 7.9},
          'rank': 3,
          'images': {
            'common': 'https://example.com/proxy-2.jpg',
          },
          'collection': {},
        },
      ],
    },
  ];
}

String _calendarHtmlPayload() {
  return '''
<div class="columns clearit">
  <div id="" class="BgmCalendar clearit">
    <ul class="large">
      <li class="week ">
        <dl>
          <dt class="Fri"><div><h3>星期五</h3></div></dt>
          <dd class="Fri">
            <ul class="coverList">
              <li style="background: center no-repeat url('//lain.bgm.tv/r/400/pic/cover/l/aa/bb/900001_test.jpg'); background-size: cover">
                <div class="info_bg">
                  <div class="info">
                    <p><a href="/subject/900001" class="nav">测试中文标题</a></p>
                    <p><a href="/subject/900001" class="nav"><small><em>テスト原題</em></small></a></p>
                  </div>
                </div>
              </li>
              <li style="background: center no-repeat url('//lain.bgm.tv/r/400/pic/cover/l/cc/dd/900002_only.jpg'); background-size: cover">
                <div class="info_bg">
                  <div class="info">
                    <p><a href="/subject/900002" class="nav"></a></p>
                    <p><a href="/subject/900002" class="nav"><small><em>只有原题</em></small></a></p>
                  </div>
                </div>
              </li>
            </ul>
          </dd>
        </dl>
      </li>
      <li class="week ">
        <dl>
          <dt class="Sat"><div><h3>星期六</h3></div></dt>
          <dd class="Sat">
            <ul class="coverList">
              <li style="background: center no-repeat url('//lain.bgm.tv/r/400/pic/cover/l/ee/ff/900003_sat.jpg'); background-size: cover">
                <div class="info_bg">
                  <div class="info">
                    <p><a href="/subject/900003" class="nav">周六番剧</a></p>
                    <p><a href="/subject/900003" class="nav"><small><em>Saturday Title</em></small></a></p>
                  </div>
                </div>
              </li>
            </ul>
          </dd>
        </dl>
      </li>
    </ul>
  </div>
</div>
''';
}
