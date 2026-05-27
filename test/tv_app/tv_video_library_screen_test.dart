import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_video_library_screen.dart';

void main() {
  testWidgets('escape pops TV video library page without waiting extra frame',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          TvVideoLibraryScreen(
                        title: '播放历史',
                        loadVideos: (_) async => [
                          _videoInfo('history_1', '历史影片'),
                        ],
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
                child: const Text('打开视频库页'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开视频库页'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('打开视频库页'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tv-video-library-screen-播放历史')),
      findsNothing,
    );
  });
}

VideoInfo _videoInfo(String id, String title) {
  return VideoInfo(
    id: id,
    source: 'test',
    title: title,
    sourceName: '测试源',
    year: '2026',
    cover: '',
    index: 1,
    totalEpisodes: 1,
    playTime: 0,
    totalTime: 0,
    saveTime: 0,
    searchTitle: title,
  );
}
