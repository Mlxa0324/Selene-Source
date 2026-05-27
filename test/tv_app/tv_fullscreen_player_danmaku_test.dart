import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/models/danmaku_model.dart';
import 'package:selene/models/search_result.dart';
import 'package:selene/models/video_info.dart';
import 'package:selene/tv_app/screens/tv_fullscreen_player_screen.dart';
import 'package:selene/tv_app/services/tv_danmaku_service.dart';
import 'package:selene/widgets/player_settings_panel.dart';
import 'package:selene/widgets/video_player_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('TV fullscreen player auto matches danmaku before opening manual match',
      (tester) async {
    final events = <String>[];
    var controllerCreated = false;

    await tester.pumpWidget(
      MaterialApp(
        home: TvFullscreenPlayerScreen(
          videoInfo: VideoInfo(
            id: 'video_1',
            source: 'source_a',
            title: '进击的巨人',
            sourceName: '主线路',
            year: '2023',
            cover: '',
            index: 1,
            totalEpisodes: 1,
            playTime: 0,
            totalTime: 0,
            saveTime: 0,
            searchTitle: '进击的巨人',
          ),
          currentDetail: SearchResult(
            id: 'video_1',
            title: '进击的巨人',
            poster: '',
            episodes: const ['https://example.com/1.m3u8'],
            episodesTitles: const ['第1集'],
            source: 'source_a',
            sourceName: '主线路',
            year: '2023',
          ),
          sources: const [],
          danmakuService: _FakeTvDanmakuService(
            onAutoMatch: () async {
              events.add('auto_match');
              return TvDanmakuLoadResult(
                episodeId: 9527,
                comments: [
                  DanmakuComment(
                    cid: 1,
                    p: '1.0,1,16777215',
                    m: '来了',
                    t: 0,
                  ),
                ],
              );
            },
          ),
          playerBuilder: (_, onControllerCreated) {
            if (!controllerCreated) {
              controllerCreated = true;
              onControllerCreated(
                _FakeVideoPlayerWidgetController(
                  isPlaying: true,
                  currentPosition: const Duration(seconds: 6),
                  duration: const Duration(minutes: 24),
                  onUpdateDataSource: (url, {startAt, headers}) async {},
                ),
              );
            }
            return const ColoredBox(color: Colors.black);
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(events, isNotEmpty);
    expect(events.every((event) => event == 'auto_match'), isTrue);
  });
}

class _FakeTvDanmakuService extends TvDanmakuService {
  _FakeTvDanmakuService({
    required this.onAutoMatch,
  });

  final Future<TvDanmakuLoadResult?> Function() onAutoMatch;

  @override
  Future<TvDanmakuLoadResult?> loadDanmaku({
    required String currentSource,
    required String currentId,
    required int episodeIndex,
    required String videoTitle,
    required String sourceName,
    String? episodeTitle,
  }) {
    return onAutoMatch();
  }
}

class _FakeVideoPlayerWidgetController implements VideoPlayerWidgetController {
  _FakeVideoPlayerWidgetController({
    required this.isPlaying,
    required this.currentPosition,
    required this.duration,
    this.onUpdateDataSource,
  });

  @override
  final bool isPlaying;

  @override
  final Duration? currentPosition;

  @override
  final Duration? duration;

  @override
  bool get isLoading => false;

  final Future<void> Function(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  })? onUpdateDataSource;

  @override
  void addProgressListener(VoidCallback listener) {}

  @override
  Future<void> dispose() async {}

  @override
  void exitWebFullscreen() {}

  @override
  bool get isPipMode => false;

  @override
  double get playbackSpeed => 1.0;

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  void removeProgressListener(VoidCallback listener) {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  void setVideoFit(VideoFitType fitType) {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> updateDataSource(
    String url, {
    Duration? startAt,
    Map<String, String>? headers,
  }) async {
    await onUpdateDataSource?.call(url, startAt: startAt, headers: headers);
  }

  @override
  Size? get videoSize => null;

  @override
  double? get volume => 1.0;
}
