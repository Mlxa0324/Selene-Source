import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selene/widgets/video_player_widget.dart';

void main() {
  group('VideoPlayerWidget Android PiP handoff wiring', () {
    test('Android WebView PiP 进入时会 arm 延迟接管而不是预切原生', () {
      expect(
        VideoPlayerWidget.debugShouldArmAndroidPipWebViewHandoff(
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

      expect(
        VideoPlayerWidget.debugShouldPrepareNativePlaybackForAndroidPip(
          isAndroid: true,
          shouldArmForPip: true,
        ),
        isFalse,
      );
    });

    test('PiP visible/resumed 时不会触发后台接管调度', () {
      expect(
        VideoPlayerWidget.debugShouldScheduleAndroidPipBackgroundHandoff(
          state: AppLifecycleState.resumed,
          isAndroid: true,
          isPipMode: true,
          handoffArmed: true,
        ),
        isFalse,
      );
    });

    test('PiP stopped 时会取消延迟接管', () {
      expect(
        VideoPlayerWidget.debugShouldCancelAndroidPipBackgroundHandoff(
          state: AppLifecycleState.inactive,
          isAndroid: true,
          isPipMode: false,
          handoffArmed: true,
        ),
        isTrue,
      );
    });
  });
}
