import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selene/config/tv_player_kernel.dart';
import 'package:selene/models/playback_preload.dart';
import 'package:selene/services/user_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    UserDataService.debugResetMemoryCaches();
  });

  test('getPlaybackPreloadLevel defaults to medium when nothing is stored',
      () async {
    SharedPreferences.setMockInitialValues({});

    expect(
      await UserDataService.getPlaybackPreloadLevel(),
      PlaybackPreloadLevel.medium,
    );
  });

  test('getAdFilterEnabled defaults to true when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});

    expect(
      await UserDataService.getAdFilterEnabled(),
      isTrue,
    );
  });

  test('getTvPlayerKernel defaults to exo when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});

    expect(
      await UserDataService.getTvPlayerKernel(),
      TvPlayerKernel.exo,
    );
  });

  test('getPlaybackPreloadLevel falls back to legacy unified bool key',
      () async {
    SharedPreferences.setMockInitialValues({
      'playback_preload_enabled_v1': false,
    });

    expect(
      await UserDataService.getPlaybackPreloadLevel(),
      PlaybackPreloadLevel.off,
    );
  });

  test('getPlaybackPreloadLevel falls back to legacy media kit key', () async {
    SharedPreferences.setMockInitialValues({
      'media_kit_preload_enabled': false,
    });

    expect(
      await UserDataService.getPlaybackPreloadLevel(),
      PlaybackPreloadLevel.off,
    );
  });

  test('savePlaybackPreloadLevel writes the unified level key', () async {
    SharedPreferences.setMockInitialValues({});

    await UserDataService.savePlaybackPreloadLevel(PlaybackPreloadLevel.medium);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('playback_preload_level_v1'), 'medium');
  });

  test('saveTvPlayerKernel writes the TV player kernel key', () async {
    SharedPreferences.setMockInitialValues({});

    await UserDataService.saveTvPlayerKernel(TvPlayerKernel.webView);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tv_player_kernel_v1'), 'webview');
  });

  test('getM3u8ProxyUrl uses in-memory cache after first read', () async {
    SharedPreferences.setMockInitialValues({
      'm3u8_proxy_url': 'https://proxy-a.example.com/',
    });

    expect(
      await UserDataService.getM3u8ProxyUrl(),
      'https://proxy-a.example.com/',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('m3u8_proxy_url', 'https://proxy-b.example.com/');

    expect(
      await UserDataService.getM3u8ProxyUrl(),
      'https://proxy-a.example.com/',
    );

    UserDataService.debugResetMemoryCaches();
    expect(
      await UserDataService.getM3u8ProxyUrl(),
      'https://proxy-b.example.com/',
    );
  });

  test('getDoubanImageSourceKey uses memory cache and save refreshes it',
      () async {
    SharedPreferences.setMockInitialValues({
      'douban_image_source': 'direct',
    });

    expect(await UserDataService.getDoubanImageSourceKey(), 'direct');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('douban_image_source', 'official_cdn');
    expect(await UserDataService.getDoubanImageSourceKey(), 'direct');

    await UserDataService.saveDoubanImageSource('豆瓣官方精品 CDN');
    expect(
      await UserDataService.getDoubanImageSourceKey(),
      'official_cdn',
    );
  });
}
