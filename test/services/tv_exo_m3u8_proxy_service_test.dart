import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/m3u8_service.dart';
import 'package:selene/services/tv_exo_m3u8_proxy_service.dart';

void main() {
  setUp(() async {
    await TvExoM3u8ProxyService.instance.debugReset();
  });

  tearDown(() async {
    await TvExoM3u8ProxyService.instance.debugReset();
  });

  test('filterAdsFromM3U8 removes explicit ad blocks and resolves urls', () {
    const manifest = '''
#EXTM3U
#EXTINF:10,
seg-0.ts
#EXT-X-CUE-OUT:30
#EXTINF:10,
ad-0.ts
#EXT-X-CUE-IN
#EXTINF:10,
seg-1.ts
#EXT-X-KEY:METHOD=AES-128,URI="enc.key"
''';

    final filtered = M3U8Service.filterAdsFromM3U8(
      manifest,
      'https://video.example.com/path/index.m3u8',
    );

    expect(filtered, isNot(contains('#EXT-X-CUE-OUT')));
    expect(filtered, isNot(contains('#EXT-X-CUE-IN')));
    expect(filtered, isNot(contains('ad-0.ts')));
    expect(filtered, contains('https://video.example.com/path/seg-0.ts'));
    expect(filtered, contains('https://video.example.com/path/seg-1.ts'));
    expect(filtered, contains('URI="https://video.example.com/path/enc.key"'));
  });

  test('proxy rewrites nested manifests and forwards request headers', () async {
    final requestedHeadersByPath = <String, String?>{};
    final upstreamServer =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await upstreamServer.close(force: true);
    });

    upstreamServer.listen((request) async {
      requestedHeadersByPath[request.uri.path] =
          request.headers.value('x-test-token');
      request.response.headers.contentType =
          ContentType('application', 'vnd.apple.mpegurl');

      switch (request.uri.path) {
        case '/master.m3u8':
          request.response.write('''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=1600000
variant.m3u8
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="main",DEFAULT=YES,URI="audio.m3u8"
''');
          break;
        case '/variant.m3u8':
          request.response.write('''
#EXTM3U
#EXTINF:10,
seg-0.ts
#EXT-X-CUE-OUT:30
#EXTINF:10,
ad-0.ts
#EXT-X-CUE-IN
#EXTINF:10,
seg-1.ts
#EXT-X-KEY:METHOD=AES-128,URI="enc.key"
''');
          break;
        case '/audio.m3u8':
          request.response.write('''
#EXTM3U
#EXTINF:10,
audio-0.aac
''');
          break;
        default:
          request.response.statusCode = HttpStatus.notFound;
          break;
      }

      await request.response.close();
    });

    final masterUrl =
        'http://127.0.0.1:${upstreamServer.port}/master.m3u8';
    final proxyUrl = await TvExoM3u8ProxyService.instance.resolvePlaybackUrl(
      url: masterUrl,
      adFilterEnabled: true,
      headers: const <String, String>{
        'X-Test-Token': 'selene-tv',
      },
    );

    final masterManifest = await _readText(proxyUrl);
    expect(masterManifest, contains('/manifest?'));

    final nestedProxyUrl = _firstProxyUrlFromManifest(masterManifest);
    final nestedManifest = await _readText(nestedProxyUrl);

    expect(nestedManifest, isNot(contains('#EXT-X-CUE-OUT')));
    expect(nestedManifest, isNot(contains('#EXT-X-CUE-IN')));
    expect(nestedManifest, isNot(contains('ad-0.ts')));
    expect(
      nestedManifest,
      contains('http://127.0.0.1:${upstreamServer.port}/seg-0.ts'),
    );
    expect(
      nestedManifest,
      contains('http://127.0.0.1:${upstreamServer.port}/seg-1.ts'),
    );
    expect(
      nestedManifest,
      contains('URI="http://127.0.0.1:${upstreamServer.port}/enc.key"'),
    );

    expect(requestedHeadersByPath['/master.m3u8'], 'selene-tv');
    expect(requestedHeadersByPath['/variant.m3u8'], 'selene-tv');
  });
}

/// 读取代理返回的文本内容。
Future<String> _readText(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final bytes = await consolidateHttpClientResponseBytes(response);
    return utf8.decode(bytes);
  } finally {
    client.close(force: true);
  }
}

/// 从代理后的主清单里提取第一个嵌套代理地址。
String _firstProxyUrlFromManifest(String manifest) {
  for (final line in const LineSplitter().convert(manifest)) {
    if (line.contains('/manifest?')) {
      return line.trim();
    }
  }
  throw StateError('未找到嵌套代理地址');
}
