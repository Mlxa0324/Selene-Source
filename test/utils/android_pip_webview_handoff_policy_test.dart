import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/utils/android_pip_webview_handoff_policy.dart';

void main() {
  group('AndroidPipWebViewHandoffPolicy', () {
    test('WebView 在线播放开启息屏播放时进入 PiP 会 arm 延迟接管', () {
      expect(
        AndroidPipWebViewHandoffPolicy.shouldArmForPip(
          isAndroid: true,
          screenOffPlaybackEnabled: true,
          usesWebViewAdapter: true,
          isLocal: false,
          canUseNativeBackgroundPlayback: true,
          backgroundPlaybackActive: false,
          pipNativeTransitioning: false,
        ),
        isTrue,
      );
    });

    test('PiP 仍可见且生命周期为 resumed 时不启动后台接管计时', () {
      expect(
        AndroidPipWebViewHandoffPolicy.shouldStartBackgroundHandoffTimer(
          state: AppLifecycleState.resumed,
          isAndroid: true,
          isPipMode: true,
          handoffArmed: true,
        ),
        isFalse,
      );
    });

    test('自动进入 PiP 后若满足 WebView 接管条件，会自动 arm 延迟接管', () {
      expect(
        AndroidPipWebViewHandoffPolicy.shouldArmBackgroundHandoffOnPipStarted(
          isAndroid: true,
          canUseHandoff: true,
          handoffArmed: false,
        ),
        isTrue,
      );
    });

    test('已经 arm 的 PiP started 回调不重复 arm', () {
      expect(
        AndroidPipWebViewHandoffPolicy.shouldArmBackgroundHandoffOnPipStarted(
          isAndroid: true,
          canUseHandoff: true,
          handoffArmed: true,
        ),
        isFalse,
      );
    });

    test('PiP 离开可见阶段时启动后台接管计时', () {
      expect(
        AndroidPipWebViewHandoffPolicy.shouldStartBackgroundHandoffTimer(
          state: AppLifecycleState.paused,
          isAndroid: true,
          isPipMode: true,
          handoffArmed: true,
        ),
        isTrue,
      );
    });

    test('PiP 回到 resumed 时取消后台接管', () {
      expect(
        AndroidPipWebViewHandoffPolicy.shouldCancelBackgroundHandoff(
          state: AppLifecycleState.resumed,
          isAndroid: true,
          isPipMode: true,
          handoffArmed: true,
        ),
        isTrue,
      );
    });
  });
}
