import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/api_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/services/tv_account_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saveCredentials exits local mode and writes shared account storage',
      () async {
    SharedPreferences.setMockInitialValues({
      'is_local_mode': true,
      'server_url': 'https://old.example.com',
      'username': 'old_user',
      'password': 'old_password',
      'cookies': 'legacy_cookie=value',
    });

    final service = TvAccountConfigService();
    final result = await service.saveCredentials(
      const TvServerCredentials(
        serverUrl: 'https://server.example.com/',
        username: 'demo_user',
        password: 'demo_password',
      ),
    );

    final savedUserData = await UserDataService.getAllUserData();

    expect(result.success, isTrue);
    expect(savedUserData['serverUrl'], 'https://server.example.com');
    expect(savedUserData['username'], 'demo_user');
    expect(savedUserData['password'], 'demo_password');
    // 切换成新的服务器账号后，旧 cookies 不能继续沿用。
    expect(savedUserData['cookies'], isEmpty);
    // 仅保存服务器配置后，应用也应该退出本地模式，后续链路才能真正吃到这份配置。
    expect(await UserDataService.getIsLocalMode(), isFalse);
  });

  test('clearSessionCookies keeps saved tv server config for next reopen',
      () async {
    SharedPreferences.setMockInitialValues({});
    await UserDataService.saveUserData(
      serverUrl: 'https://server.example.com',
      username: 'demo_user',
      password: 'demo_password',
      cookies: 'sid=expired',
    );

    await UserDataService.clearSessionCookies();

    final savedUserData = await UserDataService.getAllUserData();

    // TV 设置页重新进入时，仍需要回显这份已保存的服务器配置。
    expect(savedUserData['serverUrl'], 'https://server.example.com');
    expect(savedUserData['username'], 'demo_user');
    expect(savedUserData['password'], 'demo_password');
    expect(savedUserData['cookies'], isNull);
  });

  test('authenticated tv request auto logs in when cookies are missing',
      () async {
    SharedPreferences.setMockInitialValues({});
    final server = await _startAuthTestServer();
    addTearDown(server.close);

    await UserDataService.saveUserData(
      serverUrl: 'http://127.0.0.1:${server.port}',
      username: 'demo_user',
      password: 'demo_password',
      cookies: '',
    );

    final resources = await ApiService.getSearchResources();
    final savedUserData = await UserDataService.getAllUserData();

    expect(resources, hasLength(1));
    expect(resources.first.key, 'demo');
    expect(savedUserData['serverUrl'], 'http://127.0.0.1:${server.port}');
    expect(savedUserData['username'], 'demo_user');
    expect(savedUserData['password'], 'demo_password');
    expect(savedUserData['cookies'], contains('sid=fresh'));
  });

  test('expired tv cookies trigger auto login retry without erasing config',
      () async {
    SharedPreferences.setMockInitialValues({});
    final server = await _startAuthTestServer();
    addTearDown(server.close);

    await UserDataService.saveUserData(
      serverUrl: 'http://127.0.0.1:${server.port}',
      username: 'demo_user',
      password: 'demo_password',
      cookies: 'sid=expired',
    );

    final resources = await ApiService.getSearchResources();
    final savedUserData = await UserDataService.getAllUserData();

    expect(resources, hasLength(1));
    expect(resources.first.name, '演示源');
    expect(savedUserData['serverUrl'], 'http://127.0.0.1:${server.port}');
    expect(savedUserData['username'], 'demo_user');
    expect(savedUserData['password'], 'demo_password');
    expect(savedUserData['cookies'], contains('sid=fresh'));
  });
}

/// 启动 TV 鉴权链路测试服务器。
///
/// `/api/login` 成功时回写新 cookies，`/api/search/resources` 只有拿到新 cookies 才返回数据。
Future<HttpServer> _startAuthTestServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final path = request.uri.path;
    if (request.method == 'POST' && path == '/api/login') {
      final body = await utf8.decoder.bind(request).join();
      final payload = json.decode(body) as Map<String, dynamic>;
      final username = payload['username']?.toString() ?? '';
      final password = payload['password']?.toString() ?? '';
      if (username == 'demo_user' && password == 'demo_password') {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.add(
          HttpHeaders.setCookieHeader,
          'sid=fresh; Path=/',
        );
        request.response.write(json.encode({'success': true}));
      } else {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write(json.encode({'message': 'unauthorized'}));
      }
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && path == '/api/search/resources') {
      final cookie = request.headers.value(HttpHeaders.cookieHeader) ?? '';
      if (cookie.contains('sid=fresh')) {
        request.response.statusCode = HttpStatus.ok;
        request.response.write(
          json.encode([
            {
              'key': 'demo',
              'name': '演示源',
              'api': 'https://demo.example.com/api.php/provide/vod',
              'detail': '',
              'from': 'demo',
              'disabled': false,
            },
          ]),
        );
      } else {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write(json.encode({'message': 'unauthorized'}));
      }
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  });
  return server;
}
