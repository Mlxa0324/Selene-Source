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
        'phase': 'idle',
        'errorCode': null,
        'errorMessage': null,
      });

      expect(state, isNotNull);
      expect(state!.isActive, isTrue);
      expect(state.isPlaying, isFalse);
      expect(state.position, const Duration(seconds: 42));
      expect(state.duration, const Duration(minutes: 24));
      expect(state.phase, AndroidBackgroundPlaybackPhase.idle);
    });

    test('parses starting background playback state payload', () {
      final state = AndroidMediaSessionBridge.parseBackgroundPlaybackState({
        'isActive': true,
        'isPlaying': false,
        'positionMs': 42000,
        'durationMs': 1440000,
        'phase': 'starting',
        'errorCode': null,
        'errorMessage': null,
      });

      expect(state, isNotNull);
      expect(state!.phase, AndroidBackgroundPlaybackPhase.starting);
      expect(state.errorCode, isNull);
      expect(state.errorMessage, isNull);
    });

    test('parses ready background playback state payload', () {
      final state = AndroidMediaSessionBridge.parseBackgroundPlaybackState({
        'isActive': true,
        'isPlaying': true,
        'positionMs': 43000,
        'durationMs': 1440000,
        'phase': 'ready',
        'errorCode': null,
        'errorMessage': null,
      });

      expect(state, isNotNull);
      expect(state!.phase, AndroidBackgroundPlaybackPhase.ready);
      expect(state.isPlaying, isTrue);
    });

    test('parses error background playback state payload', () {
      final state = AndroidMediaSessionBridge.parseBackgroundPlaybackState({
        'isActive': false,
        'isPlaying': false,
        'positionMs': 42000,
        'durationMs': 1440000,
        'phase': 'error',
        'errorCode': 'ERROR_CODE_IO_BAD_HTTP_STATUS',
        'errorMessage': '403',
      });

      expect(state, isNotNull);
      expect(state!.phase, AndroidBackgroundPlaybackPhase.error);
      expect(state.errorCode, 'ERROR_CODE_IO_BAD_HTTP_STATUS');
      expect(state.errorMessage, '403');
    });

    test('defaults unknown background playback phase to idle', () {
      final state = AndroidMediaSessionBridge.parseBackgroundPlaybackState({
        'isActive': false,
        'isPlaying': false,
        'positionMs': 0,
        'durationMs': 0,
        'phase': 'weird_value',
      });

      expect(state, isNotNull);
      expect(state!.phase, AndroidBackgroundPlaybackPhase.idle);
    });

    test('waitForBackgroundPlaybackReady returns ready state before timeout',
        () async {
      final states = <AndroidBackgroundPlaybackState?>[
        const AndroidBackgroundPlaybackState(
          isActive: true,
          isPlaying: false,
          position: Duration.zero,
          duration: Duration.zero,
          phase: AndroidBackgroundPlaybackPhase.starting,
        ),
        const AndroidBackgroundPlaybackState(
          isActive: true,
          isPlaying: true,
          position: Duration(seconds: 1),
          duration: Duration(minutes: 24),
          phase: AndroidBackgroundPlaybackPhase.ready,
        ),
      ];

      final bridge = AndroidMediaSessionBridge(
        platformOverride: true,
        backgroundPlaybackStateFetcher: () async => states.removeAt(0),
      );

      final state = await bridge.waitForBackgroundPlaybackReady(
        timeout: const Duration(milliseconds: 80),
        pollInterval: const Duration(milliseconds: 1),
      );

      expect(state, isNotNull);
      expect(state!.phase, AndroidBackgroundPlaybackPhase.ready);
      expect(state.isPlaying, isTrue);
    });

    test('waitForBackgroundPlaybackReady returns error state immediately',
        () async {
      final bridge = AndroidMediaSessionBridge(
        platformOverride: true,
        backgroundPlaybackStateFetcher: () async =>
            const AndroidBackgroundPlaybackState(
          isActive: false,
          isPlaying: false,
          position: Duration.zero,
          duration: Duration.zero,
          phase: AndroidBackgroundPlaybackPhase.error,
          errorCode: 'ERROR_CODE_IO_BAD_HTTP_STATUS',
          errorMessage: '403',
        ),
      );

      final state = await bridge.waitForBackgroundPlaybackReady(
        timeout: const Duration(milliseconds: 80),
        pollInterval: const Duration(milliseconds: 1),
      );

      expect(state, isNotNull);
      expect(state!.phase, AndroidBackgroundPlaybackPhase.error);
      expect(state.errorMessage, '403');
    });

    test('waitForBackgroundPlaybackReady returns null on timeout', () async {
      final bridge = AndroidMediaSessionBridge(
        platformOverride: true,
        backgroundPlaybackStateFetcher: () async =>
            const AndroidBackgroundPlaybackState(
          isActive: true,
          isPlaying: false,
          position: Duration.zero,
          duration: Duration.zero,
          phase: AndroidBackgroundPlaybackPhase.starting,
        ),
      );

      final state = await bridge.waitForBackgroundPlaybackReady(
        timeout: const Duration(milliseconds: 10),
        pollInterval: const Duration(milliseconds: 1),
      );

      expect(state, isNull);
    });
  });
}
