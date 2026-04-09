import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/utils/mobile_playback_lifecycle_policy.dart';

void main() {
  group('MobilePlaybackLifecyclePolicy', () {
    test('Android 在 paused 时立即切后台音频', () {
      expect(
        MobilePlaybackLifecyclePolicy.resolveAndroidBackgroundPlaybackAction(
          state: AppLifecycleState.paused,
          canUseBackgroundPlayback: true,
          backgroundPlaybackActive: false,
          isPipMode: false,
        ),
        AndroidBackgroundPlaybackLifecycleAction.startImmediately,
      );
    });

    test('Android 在 inactive 时仅安排延迟后台接力', () {
      expect(
        MobilePlaybackLifecyclePolicy.resolveAndroidBackgroundPlaybackAction(
          state: AppLifecycleState.inactive,
          canUseBackgroundPlayback: true,
          backgroundPlaybackActive: false,
          isPipMode: false,
        ),
        AndroidBackgroundPlaybackLifecycleAction.scheduleDelayedStart,
      );
    });

    test('Android 返回前台时恢复前台播放器', () {
      expect(
        MobilePlaybackLifecyclePolicy.resolveAndroidBackgroundPlaybackAction(
          state: AppLifecycleState.resumed,
          canUseBackgroundPlayback: true,
          backgroundPlaybackActive: true,
          isPipMode: false,
        ),
        AndroidBackgroundPlaybackLifecycleAction.restoreForeground,
      );
    });

    test('Android 处于 PiP 时不触发后台音频切换', () {
      expect(
        MobilePlaybackLifecyclePolicy.resolveAndroidBackgroundPlaybackAction(
          state: AppLifecycleState.paused,
          canUseBackgroundPlayback: true,
          backgroundPlaybackActive: false,
          isPipMode: true,
        ),
        AndroidBackgroundPlaybackLifecycleAction.none,
      );
    });

    test('Android 已在后台音频接管时不重复触发切换', () {
      expect(
        MobilePlaybackLifecyclePolicy.resolveAndroidBackgroundPlaybackAction(
          state: AppLifecycleState.hidden,
          canUseBackgroundPlayback: true,
          backgroundPlaybackActive: true,
          isPipMode: false,
        ),
        AndroidBackgroundPlaybackLifecycleAction.none,
      );
    });

    test('Android 在进入后台前原本正在播放时，记录后台接管意图', () {
      expect(
        MobilePlaybackLifecyclePolicy.shouldRememberAndroidBackgroundPlaybackIntent(
          state: AppLifecycleState.hidden,
          isAndroid: true,
          canUseBackgroundPlayback: true,
          backgroundPlaybackActive: false,
          isPipMode: false,
          wasPlayingBeforeBackground: true,
        ),
        isTrue,
      );
    });

    test('Android 若进入后台前本就未播放，则不记录后台接管意图', () {
      expect(
        MobilePlaybackLifecyclePolicy.shouldRememberAndroidBackgroundPlaybackIntent(
          state: AppLifecycleState.paused,
          isAndroid: true,
          canUseBackgroundPlayback: true,
          backgroundPlaybackActive: false,
          isPipMode: false,
          wasPlayingBeforeBackground: false,
        ),
        isFalse,
      );
    });

    test('Android 后台接管启动时允许使用已记录的前台播放意图', () {
      expect(
        MobilePlaybackLifecyclePolicy.shouldStartAndroidBackgroundPlayback(
          adapterPlaying: false,
          lastKnownPlaying: false,
          rememberedPlaybackIntent: true,
        ),
        isTrue,
      );
    });

    test('iOS WebView 后台前若原本在播，记录前台恢复意图', () {
      expect(
        MobilePlaybackLifecyclePolicy.shouldRememberIosForegroundResume(
          state: AppLifecycleState.hidden,
          isIOS: true,
          usesWebViewAdapter: true,
          isPipMode: false,
          wasPlayingBeforeBackground: true,
        ),
        isTrue,
      );
    });

    test('iOS 返回前台时按记录执行恢复', () {
      expect(
        MobilePlaybackLifecyclePolicy.shouldAttemptIosForegroundResume(
          state: AppLifecycleState.resumed,
          isIOS: true,
          usesWebViewAdapter: true,
          isPipMode: false,
          pendingForegroundResume: true,
        ),
        isTrue,
      );
    });

    test('iOS 未记录恢复意图时不执行恢复', () {
      expect(
        MobilePlaybackLifecyclePolicy.shouldAttemptIosForegroundResume(
          state: AppLifecycleState.resumed,
          isIOS: true,
          usesWebViewAdapter: true,
          isPipMode: false,
          pendingForegroundResume: false,
        ),
        isFalse,
      );
    });

    test('iOS 回前台后若位置持续不推进且仍缓冲，则触发重载兜底', () {
      expect(
        MobilePlaybackLifecyclePolicy.shouldReloadIosForegroundPlayback(
          isIOS: true,
          usesWebViewAdapter: true,
          isPipMode: false,
          pendingForegroundResume: true,
          positionBeforeResume: const Duration(seconds: 12),
          positionAfterResumeGracePeriod:
              const Duration(seconds: 12, milliseconds: 120),
          isPlayingAfterResumeGracePeriod: false,
          isBufferingAfterResumeGracePeriod: true,
        ),
        isTrue,
      );
    });

    test('iOS 回前台后若位置已恢复推进，则不触发重载兜底', () {
      expect(
        MobilePlaybackLifecyclePolicy.shouldReloadIosForegroundPlayback(
          isIOS: true,
          usesWebViewAdapter: true,
          isPipMode: false,
          pendingForegroundResume: true,
          positionBeforeResume: const Duration(seconds: 12),
          positionAfterResumeGracePeriod:
              const Duration(seconds: 12, milliseconds: 420),
          isPlayingAfterResumeGracePeriod: true,
          isBufferingAfterResumeGracePeriod: false,
        ),
        isFalse,
      );
    });
  });
}
