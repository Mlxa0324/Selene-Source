import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class DoubanVerifyService {
  final String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  final Map<String, String> _cookieCache = {};
  final Map<String, DateTime> _cookieExpiries = {};

  Future<http.Response> fetchWithVerify(String targetUrl,
      {Map<String, String>? headers}) async {
    _cleanupExpiredCookies();
    final uri = Uri.parse(targetUrl);
    var response = await http.get(uri, headers: {
      'User-Agent': userAgent,
      'Cookie': _getCookieString(),
      'Referer': 'https://movie.douban.com/',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      ...?headers,
    });
    _updateCookies(response);
    if (!response.body.contains('id="sec"')) return response;
    String html = response.body;
    String? tok = _extractValue(html, 'tok'),
        cha = _extractValue(html, 'cha'),
        red = _extractValue(html, 'red');
    if (tok == null || cha == null || red == null) return response;
    int sol = await _solvePoW(cha);
    var verifyResponse =
        await http.post(Uri.parse('https://sec.douban.com/c'), body: {
      'tok': tok,
      'cha': cha,
      'sol': sol.toString(),
      'red': red
    }, headers: {
      'User-Agent': userAgent,
      'Referer': response.request!.url.toString(),
      'Cookie': _getCookieString(),
      'Content-Type': 'application/x-www-form-urlencoded',
    });
    _updateCookies(verifyResponse);
    return await http.get(uri,
        headers: {'User-Agent': userAgent, 'Cookie': _getCookieString()});
  }

  Future<int> _solvePoW(String cha, {int difficulty = 4}) async {
    int nonce = 0;
    String targetPrefix = '0' * difficulty;
    while (true) {
      nonce++;
      String input = cha + nonce.toString();
      if (sha512
          .convert(utf8.encode(input))
          .toString()
          .startsWith(targetPrefix)) return nonce;
      if (nonce % 10000 == 0) await Future.delayed(Duration.zero);
    }
  }

  String? _extractValue(String html, String name) =>
      RegExp('id="$name" name="$name" value="(.*?)"')
          .firstMatch(html)
          ?.group(1);

  void _updateCookies(http.Response response) {
    String? setCookie = response.headers['set-cookie'];
    if (setCookie == null) return;
    for (var cookieString in setCookie.split(RegExp(r',(?=[^;]+?=)'))) {
      final parts = cookieString.split(';');
      final firstPart = parts[0], separatorIndex = firstPart.indexOf('=');
      if (separatorIndex == -1) continue;
      final name = firstPart.substring(0, separatorIndex).trim(),
          value = firstPart.substring(separatorIndex + 1).trim();
      if (name.isEmpty) continue;
      _cookieCache[name] = value;
      DateTime? expiry;
      for (var i = 1; i < parts.length; i++) {
        final attr = parts[i].trim().toLowerCase();
        if (attr.startsWith('max-age=')) {
          final seconds = int.tryParse(attr.substring(8));
          if (seconds != null) {
            expiry = DateTime.now().add(Duration(seconds: seconds));
          }
        }
      }
      if (name == 'dbsawcv1' && expiry == null) {
        expiry = DateTime.now().add(const Duration(seconds: 300));
      }
      if (expiry != null) {
        _cookieExpiries[name] = expiry;
      } else {
        _cookieExpiries.remove(name);
      }
    }
  }

  String _getCookieString() {
    _cleanupExpiredCookies();
    if (_cookieCache.containsKey('dbsawcv1')) {
      _cookieExpiries['dbsawcv1'] = DateTime.now().add(const Duration(seconds: 300));
    }
    return _cookieCache.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void _cleanupExpiredCookies() {
    final now = DateTime.now();
    final expiredKeys = _cookieExpiries.entries
        .where((e) => now.isAfter(e.value))
        .map((e) => e.key)
        .toList();
    for (var key in expiredKeys) {
      _cookieCache.remove(key);
      _cookieExpiries.remove(key);
    }
  }
}
