import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_favorites_screen.dart';
import 'package:selene/tv_app/screens/tv_history_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.physicalSizeTestValue = const Size(1920, 1080);
    binding.window.devicePixelRatioTestValue = 1;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  });

  testWidgets('renders standalone history page as vertical grid',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvHistoryScreen(
          loadVideos: (_) async => List.generate(
            8,
            (index) => _videoInfo('history_$index', '历史 $index'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final grid = find.byKey(const ValueKey('tv-video-grid'));
    final scroll = find.byKey(const ValueKey('tv-video-grid-scroll'));
    expect(grid, findsOneWidget);
    expect(scroll, findsOneWidget);
    expect(
      tester.widget<CustomScrollView>(scroll).scrollDirection,
      Axis.vertical,
    );
    expect(find.text('播放历史'), findsOneWidget);
    expect(find.text('历史 0'), findsOneWidget);
  });

  testWidgets('renders standalone favorites page as vertical grid',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TvFavoritesScreen(
          loadVideos: (_) async => List.generate(
            8,
            (index) => _videoInfo('favorite_$index', '收藏 $index'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final grid = find.byKey(const ValueKey('tv-video-grid'));
    final scroll = find.byKey(const ValueKey('tv-video-grid-scroll'));
    expect(grid, findsOneWidget);
    expect(scroll, findsOneWidget);
    expect(
      tester.widget<CustomScrollView>(scroll).scrollDirection,
      Axis.vertical,
    );
    expect(find.text('收藏夹'), findsOneWidget);
    expect(find.text('收藏 0'), findsOneWidget);
  });
}

VideoInfo _videoInfo(String id, String title) {
  return VideoInfo(
    id: id,
    title: title,
    source: 'test',
    sourceName: '测试源',
    cover: '',
    year: '2025',
    index: 1,
    totalEpisodes: 1,
    playTime: 0,
    totalTime: 0,
    saveTime: 0,
    searchTitle: title,
  );
}
