import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class DoubanVerifyService {
  final String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  // 模拟缓存：存储持久化 Cookie
  final Map<String, String> _cookieCache = {};

  /// 核心方法：传入 URL，返回最终绕过验证后的响应内容
  Future<http.Response> fetchWithVerify(String targetUrl, {Map<String, String>? headers}) async {
    final uri = Uri.parse(targetUrl);

    // 步骤 1: 尝试使用缓存的 Cookie 直接访问
    if (_cookieCache.containsKey('dbsawcv1')) {
      debugPrint(' -> 发现缓存的 dbsawcv1 Cookie，尝试直接访问...');
    }

    var response = await http.get(uri, headers: {
      'User-Agent': userAgent,
      'Cookie': _getCookieString(),
      'Referer': 'https://movie.douban.com/',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      ...?headers,
    });

    _updateCookies(response);

    // 如果页面没被拦截，直接返回内容
    if (!response.body.contains('id="sec"')) {
      return response;
    }

    // debugPrint(' -> 检测到验证页面，准备执行逆向流程。');

    // 步骤 2: 提取参数
    String html = response.body;
    String? tok = _extractValue(html, 'tok');
    String? cha = _extractValue(html, 'cha');
    String? red = _extractValue(html, 'red');

    if (tok == null || cha == null || red == null) {
      return response;
    }

    // 步骤 3: 计算 PoW (sol)
    int sol = await _solvePoW(cha);

    // 步骤 4: 提交验证
    final currentUrl = response.request!.url;
    final verifyUri = Uri.parse('https://sec.douban.com/c');

    final postData = {
      'tok': tok,
      'cha': cha,
      'sol': sol.toString(),
      'red': red,
    };

    var verifyResponse = await http.post(
      verifyUri,
      body: postData,
      headers: {
        'User-Agent': userAgent,
        'Referer': currentUrl.toString(),
        'Cookie': _getCookieString(),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );

    _updateCookies(verifyResponse);

    // 步骤 5: 携带新获取的 Cookie 再次访问
    var finalResponse = await http.get(
      uri,
      headers: {
        'User-Agent': userAgent,
        'Cookie': _getCookieString(),
      },
    );
    return finalResponse;
  }

  /// 计算 PoW: 寻找满足条件的 nonce
  Future<int> _solvePoW(String cha, {int difficulty = 4}) async {
    int nonce = 0;
    String targetPrefix = '0' * difficulty;
    Stopwatch stopwatch = Stopwatch()..start();

    while (true) {
      nonce++;
      String input = cha + nonce.toString();
      var bytes = utf8.encode(input);
      var digest = sha512.convert(bytes);

      if (digest.toString().startsWith(targetPrefix)) {
        stopwatch.stop();
        return nonce;
      }

      // 防止长时间阻塞 UI 线程（如果是 Flutter 开发）
      if (nonce % 10000 == 0) await Future.delayed(Duration.zero);
    }
  }

  String? _extractValue(String html, String name) {
    final regExp = RegExp('id="$name" name="$name" value="(.*?)"');
    final match = regExp.firstMatch(html);
    return match?.group(1);
  }

  void _updateCookies(http.Response response) {
    String? setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final cookies = setCookie.split(RegExp(r',(?=[^;]+?=)'));
      for (var cookie in cookies) {
        final cookiePart = cookie.split(';')[0];
        final separatorIndex = cookiePart.indexOf('=');
        if (separatorIndex != -1) {
          final name = cookiePart.substring(0, separatorIndex).trim();
          final value = cookiePart.substring(separatorIndex + 1).trim();
          if (name.isNotEmpty) {
            _cookieCache[name] = value;
          }
        }
      }
    }
  }

  String _getCookieString() {
    return _cookieCache.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
}