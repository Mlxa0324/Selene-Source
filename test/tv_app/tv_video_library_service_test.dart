import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/play_record.dart';
import 'package:selene/services/page_cache_service.dart';
import 'package:selene/services/user_data_service.dart';
import 'package:selene/tv_app/services/tv_video_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    PageCacheService().clearAllCache();
  });

  tearDown(() async {
    PageCacheService().clearAllCache();
    await UserDataService.clearUserData();
    await UserDataService.saveIsLocalMode(false);
  });

  testWidgets('TV direct history loader bypasses cached play records',
      (tester) async {
    await UserDataService.saveIsLocalMode(false);
    await UserDataService.saveUserData(
      serverUrl: 'http://tv.test',
      username: 'tv_user',
      password: 'tv_password',
      cookies: 'sid=tv',
    );

    PageCacheService().setCache(
      'play_records',
      [
        PlayRecord(
          id: 'cached_video',
          source: 'source_cache',
          title: '缓存影片',
          sourceName: '缓存源',
          year: '2025',
          cover: '',
          index: 1,
          totalEpisodes: 1,
          playTime: 12,
          totalTime: 100,
          saveTime: 1,
          searchTitle: '缓存影片',
        ),
      ],
    );

    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cachedVideos = await TvVideoLibraryService.loadHistory(pageContext);
    expect(cachedVideos, hasLength(1));
    expect(cachedVideos.first.source, 'source_cache');
    expect(cachedVideos.first.id, 'cached_video');

    final remoteVideos =
        await TvVideoLibraryService.loadHistoryDirect(pageContext);
    expect(remoteVideos, isEmpty);
  });
}
