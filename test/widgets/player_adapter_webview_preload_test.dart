import 'package:flutter_test/flutter_test.dart';

import 'package:selene/models/playback_preload.dart';
import 'package:selene/models/player_cached_range.dart';
import 'package:selene/widgets/player_adapter.dart';

void main() {
  test('preload tuning turns off buffering targets when level is off', () {
    final tuning = resolveWebViewPreloadTuning(
      preloadLevel: PlaybackPreloadLevel.off,
    );

    expect(tuning.targetForwardBuffer, isNull);
    expect(tuning.backBufferRetention, isNull);
    expect(tuning.preloadAttribute, 'metadata');
  });

  test('preload tuning uses a one-minute forward buffer target for low', () {
    final tuning = resolveWebViewPreloadTuning(
      preloadLevel: PlaybackPreloadLevel.low,
    );

    expect(tuning.targetForwardBuffer, const Duration(minutes: 1));
    expect(tuning.backBufferRetention, const Duration(minutes: 15));
    expect(tuning.preloadAttribute, 'auto');
  });

  test('preload tuning uses a three-minute forward buffer target for medium',
      () {
    final tuning = resolveWebViewPreloadTuning(
      preloadLevel: PlaybackPreloadLevel.medium,
    );

    expect(tuning.targetForwardBuffer, const Duration(minutes: 3));
    expect(tuning.backBufferRetention, const Duration(minutes: 15));
    expect(tuning.preloadAttribute, 'auto');
  });

  test('preload tuning uses a five-minute forward buffer target for high', () {
    final tuning = resolveWebViewPreloadTuning(
      preloadLevel: PlaybackPreloadLevel.high,
    );

    expect(tuning.targetForwardBuffer, const Duration(minutes: 5));
    expect(tuning.backBufferRetention, const Duration(minutes: 15));
    expect(tuning.preloadAttribute, 'auto');
  });

  test('web view html keeps seek warmup enabled without shrinking preload', () {
    final html = buildWebViewPlayerHtmlForTest(
      url: 'https://example.com/video.m3u8',
      adFilterEnabled: false,
      preloadLevel: PlaybackPreloadLevel.medium,
      seekBoostEnabled: true,
    );

    expect(html, contains('var seekBoostEnabled = true'));
    expect(
      html,
      contains(
        'config.maxBufferLength = Math.max(30, targetForwardBufferSeconds);',
      ),
    );
    expect(html, isNot(contains('config.maxBufferLength = 8;')));
    expect(html, isNot(contains('config.maxMaxBufferLength = 16;')));
  });

  test('web view HLS fragment loads report buffered ranges', () {
    final html = buildWebViewPlayerHtmlForTest(
      url: 'https://example.com/video.m3u8',
      preloadLevel: PlaybackPreloadLevel.medium,
    );

    expect(
      html,
      contains('''
        hls.on(Hls.Events.FRAG_LOADED, function(event, data) {
          emitNetworkSpeedFromStats(data && data.stats, 0);
          // 分片加载完成后主动同步缓冲区间，避免移动端 progress 事件缺失时进度条空白。
          emitBufferedRanges();
        });'''),
    );
  });

  test('web view play command uses paused resume recovery helper', () {
    final command = buildWebViewPlayerPlayCommandForTest();

    expect(command, contains('window.resumePlaybackFromPause'));
    expect(command, contains('player.play();'));
  });

  test('web view html wakes HLS loading when resuming after pause', () {
    final html = buildWebViewPlayerHtmlForTest(
      url: 'https://example.com/video.m3u8',
      preloadLevel: PlaybackPreloadLevel.medium,
    );

    expect(html, contains('function resumePlaybackFromPause()'));
    expect(html, contains('window.hlsInstance.startLoad(resumeTime);'));
    expect(html, contains('scheduleResumePlaybackRecovery(resumeTime'));
  });

  test('decodeWebViewCachedRanges parses confirmed buffered ranges', () {
    final ranges = decodeWebViewCachedRanges([
      {
        'startMs': 0,
        'endMs': 180000,
      },
      {
        'startMs': 240000,
        'endMs': 360000,
      },
    ]);

    expect(
      ranges,
      const [
        PlayerCachedRange(
          start: Duration.zero,
          end: Duration(minutes: 3),
        ),
        PlayerCachedRange(
          start: Duration(minutes: 4),
          end: Duration(minutes: 6),
        ),
      ],
    );
  });

  test('decodeWebViewCachedRanges ignores invalid or empty ranges', () {
    final ranges = decodeWebViewCachedRanges([
      {
        'startMs': 120000,
        'endMs': 120000,
      },
      {
        'startMs': 'bad',
        'endMs': 180000,
      },
      'bad',
    ]);

    expect(ranges, isEmpty);
  });
}
