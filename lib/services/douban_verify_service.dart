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
    // debugPrint('\n[步骤 1] 访问目标地址: $targetUrl');
    if (_cookieCache.containsKey('dbsawcv1')) {
      // debugPrint(' -> 发现缓存的 dbsawcv1 Cookie，尝试直接访问...');
    }

    var response = await http.get(uri, headers: {
      'User-Agent': userAgent,
      'Cookie': _getCookieString(),
      'Referer': 'https://movie.douban.com/',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      ...?headers,
    });

    _updateCookies(response);
    // debugPrint(' -> 响应状态码: ${response.statusCode}');
    // debugPrint(' -> 实际响应 URL: ${response.request?.url}');

    // 如果页面没被拦截，直接返回内容
    if (!response.body.contains('id="sec"')) {
      // debugPrint(' -> 未检测到验证页面 (或已通过缓存绕过)，直接返回内容。');
      return response;
    }

    // debugPrint(' -> 检测到验证页面，准备执行逆向流程。');

    // 步骤 2: 提取参数
    // debugPrint('\n[步骤 2] 提取隐藏域参数:');
    String html = response.body;
    String? tok = _extractValue(html, 'tok');
    String? cha = _extractValue(html, 'cha');
    String? red = _extractValue(html, 'red');

    if (tok == null || cha == null || red == null) {
      // debugPrint(' -> [错误] 无法提取验证参数，返回原始 HTML。');
      return response;
    }
    // debugPrint(' -> tok: ${tok.substring(0, 30)}...');
    // debugPrint(' -> cha: $cha');
    // debugPrint(' -> red: $red');

    // 步骤 3: 计算 PoW (sol)
    int sol = await _solvePoW(cha);

    // 步骤 4: 提交验证
    final currentUrl = response.request!.url;
    final verifyUri = Uri.parse('https://sec.douban.com/c');
    // debugPrint('\n[步骤 4] 提交验证 POST 到: $verifyUri');

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

    // debugPrint(' -> 响应状态码: ${verifyResponse.statusCode}');
    _updateCookies(verifyResponse);
    // debugPrint('\n[当前缓存的 Cookies]:');
    // _cookieCache.forEach((key, value) => debugPrint(' -> $key: $value'));

    // 步骤 5: 携带新获取的 Cookie 再次访问
    // debugPrint('\n[步骤 5] 携带最新 Cookie 再次访问原地址...');
    var finalResponse = await http.get(
      uri,
      headers: {
        'User-Agent': userAgent,
        'Cookie': _getCookieString(),
      },
    );
    // debugPrint(' -> 响应状态码: ${finalResponse.statusCode}');

    return finalResponse;
  }

  /// 计算 PoW: 寻找满足条件的 nonce
  Future<int> _solvePoW(String cha, {int difficulty = 4}) async {
    // debugPrint('\n[步骤 3] 开始计算 PoW (difficulty=$difficulty)...');
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
        // debugPrint(' -> 计算结果 (sol/nonce): $nonce');
        // debugPrint(' -> 匹配的哈希值: ${digest.toString()}');
        // debugPrint(' -> 耗时: ${stopwatch.elapsedMilliseconds / 1000.0} 秒');
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