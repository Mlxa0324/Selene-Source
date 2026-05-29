import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:selene/tv_app/services/tv_mobile_settings_bridge.dart';

void main() {
  test('accepts mobile settings draft from local network form page', () async {
    final appliedDraftCompleter = Completer<TvMobileSettingsDraft>();
    final session = await TvMobileSettingsBridge.startSession(
      const TvMobileSettingsDraft(
        serverUrl: 'https://initial.example.com',
        username: 'demo',
        password: 'secret',
        doubanImageSource: '直连',
        adFilterEnabled: true,
        danmakuBaseApi: 'https://danmaku.initial.com/',
      ),
      (draft) {
        if (!appliedDraftCompleter.isCompleted) {
          appliedDraftCompleter.complete(draft);
        }
      },
      bindAddress: InternetAddress.loopbackIPv4,
      preferredHost: '127.0.0.1',
    );
    addTearDown(() async {
      await session.dispose();
    });

    expect(session.shareUri, isNotNull);
    expect(session.shareUri?.host, '127.0.0.1');
    expect(session.shareUri?.path, anyOf('', '/'));

    final getResponse = await http.get(session.shareUri!);
    expect(getResponse.statusCode, HttpStatus.ok);
    expect(getResponse.body, contains('Selene TV 手机配置'));
    expect(getResponse.body, contains('127.0.0.1:${session.shareUri!.port}'));

    final postResponse = await http.post(
      session.shareUri!,
      headers: const <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: <String, String>{
        'serverUrl': 'https://tv.example.com',
        'username': 'tv_user',
        'password': 'tv_password',
        'doubanImageSource': '豆瓣官方精品 CDN',
        'adFilterEnabled': 'false',
        'danmakuBaseApi': 'https://danmaku.tv.example.com/',
      },
    );

    final appliedDraft = await appliedDraftCompleter.future.timeout(
      const Duration(seconds: 3),
    );

    expect(postResponse.statusCode, HttpStatus.ok);
    expect(postResponse.body, contains('配置已发送到电视'));
    expect(session.statusNotifier.value, TvMobileSettingsBridge.appliedStatus);
    expect(appliedDraft.serverUrl, 'https://tv.example.com');
    expect(appliedDraft.username, 'tv_user');
    expect(appliedDraft.password, 'tv_password');
    expect(appliedDraft.doubanImageSource, '豆瓣官方精品 CDN');
    expect(appliedDraft.adFilterEnabled, isFalse);
    expect(appliedDraft.danmakuBaseApi, 'https://danmaku.tv.example.com/');
  });

  test('manual regenerate allocation starts from the next share port',
      () async {
    final firstSession = await TvMobileSettingsBridge.startSession(
      TvMobileSettingsDraft.empty(),
      (_) {},
      bindAddress: InternetAddress.loopbackIPv4,
      preferredHost: '127.0.0.1',
    );
    var firstSessionDisposed = false;
    addTearDown(() async {
      if (!firstSessionDisposed) {
        await firstSession.dispose();
      }
    });

    expect(firstSession.shareUri, isNotNull);
    final firstPort = firstSession.shareUri?.port;
    expect(firstPort, isNotNull);

    await firstSession.dispose();
    firstSessionDisposed = true;

    final secondSession = await TvMobileSettingsBridge.startSession(
      TvMobileSettingsDraft.empty(),
      (_) {},
      bindAddress: InternetAddress.loopbackIPv4,
      preferredHost: '127.0.0.1',
      allocateNewPort: true,
    );
    addTearDown(() async {
      await secondSession.dispose();
    });

    expect(secondSession.shareUri, isNotNull);
    expect(secondSession.shareUri?.host, firstSession.shareUri?.host);
    expect(secondSession.shareUri?.port, isNot(firstPort));
  });
}
