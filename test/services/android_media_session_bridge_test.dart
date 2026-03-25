import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/services/android_media_session_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AndroidMediaSessionBridge.channelName);
  final methodCalls = <MethodCall>[];

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methodCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AndroidMediaSessionBridge', () {
    test('builds subtitle with episode progress and source name', () {
      final state = AndroidMediaSessionBridge.buildPlaybackState(
        title: '火影忍者',
        sourceName: '最大资源',
        currentEpisodeIndex: 363,
        totalEpisodes: 720,
        artworkUrl: 'https://example.com/naruto.jpg',
        duration: const Duration(minutes: 23, seconds: 29),
        position: const Duration(minutes: 5, seconds: 16),
        isPlaying: true,
        hasPrevious: true,
        hasNext: true,
      );

      expect(state.subtitle, '第364/720集 · 最大资源');
      expect(state.toMap()['artworkUrl'], 'https://example.com/naruto.jpg');
      expect(state.toMap()['durationMs'], 1409000);
      expect(state.toMap()['positionMs'], 316000);
    });

    test('syncSession invokes method channel with normalized payload',
        () async {
      final bridge = AndroidMediaSessionBridge(platformOverride: true);
      final state = AndroidMediaSessionBridge.buildPlaybackState(
        title: '火影忍者',
        sourceName: '最大资源',
        currentEpisodeIndex: 1,
        totalEpisodes: 24,
        duration: const Duration(minutes: 24),
        position: const Duration(seconds: 42),
        isPlaying: false,
        hasPrevious: true,
        hasNext: true,
      );

      await bridge.syncSession(state);

      expect(methodCalls, hasLength(1));
      expect(methodCalls.single.method, 'syncMediaSession');
      expect(methodCalls.single.arguments, {
        'title': '火影忍者',
        'subtitle': '第2/24集 · 最大资源',
        'artworkUrl': null,
        'durationMs': 1440000,
        'positionMs': 42000,
        'isPlaying': false,
        'hasPrevious': true,
        'hasNext': true,
      });
    });

    test('does not invoke channel when platform support is disabled', () async {
      final bridge = AndroidMediaSessionBridge(platformOverride: false);
      final state = AndroidMediaSessionBridge.buildPlaybackState(
        title: '火影忍者',
        duration: const Duration(minutes: 24),
        position: Duration.zero,
        isPlaying: true,
        hasPrevious: false,
        hasNext: true,
      );

      await bridge.syncSession(state);
      await bridge.stopSession();
      await bridge.stopBackgroundPlayback();

      expect(methodCalls, isEmpty);
    });

    test('startBackgroundPlayback invokes method channel with request payload',
        () async {
      final bridge = AndroidMediaSessionBridge(platformOverride: true);

      await bridge.startBackgroundPlayback(
        const AndroidBackgroundPlaybackRequest(
          title: '火影忍者',
          subtitle: '第364/720集 · 最大资源',
          artworkUrl: 'https://example.com/naruto.jpg',
          url: 'https://example.com/naruto.m3u8',
          headers: {'Referer': 'https://example.com'},
          duration: Duration(minutes: 23, seconds: 29),
          position: Duration(minutes: 5, seconds: 16),
          speed: 1.25,
        ),
      );

      expect(methodCalls, hasLength(1));
      expect(methodCalls.single.method, 'startBackgroundPlayback');
      expect(methodCalls.single.arguments, {
        'title': '火影忍者',
        'subtitle': '第364/720集 · 最大资源',
        'artworkUrl': 'https://example.com/naruto.jpg',
        'url': 'https://example.com/naruto.m3u8',
        'headers': {'Referer': 'https://example.com'},
        'durationMs': 1409000,
        'positionMs': 316000,
        'speed': 1.25,
      });
    });

    test('does not request stop when a session was never synced', () {
      expect(
        AndroidMediaSessionBridge.shouldStopSession(
          wantsMediaSession: false,
          hasSyncedSession: false,
        ),
        isFalse,
      );
    });

    test('requests stop when a previously active session becomes unsupported',
        () {
      expect(
        AndroidMediaSessionBridge.shouldStopSession(
          wantsMediaSession: false,
          hasSyncedSession: true,
        ),
        isTrue,
      );
    });

    test('parses seek action payload from method call', () {
      final action = AndroidMediaSessionBridge.parseAction(
        const MethodCall(
          'onMediaSessionAction',
          {
            'action': 'seek',
            'positionMs': 123456,
          },
        ),
      );

      expect(action, isNotNull);
      expect(action!.type, AndroidMediaSessionActionType.seek);
      expect(action.position, const Duration(milliseconds: 123456));
    });

    test('parses background playback state payload', () {
      final state = AndroidMediaSessionBridge.parseBackgroundPlaybackState({
        'isActive': true,
        'isPlaying': false,
        'positionMs': 42000,
        'durationMs': 1440000,
      });

      expect(state, isNotNull);
      expect(state!.isActive, isTrue);
      expect(state.isPlaying, isFalse);
      expect(state.position, const Duration(seconds: 42));
      expect(state.duration, const Duration(minutes: 24));
    });
  });
}
