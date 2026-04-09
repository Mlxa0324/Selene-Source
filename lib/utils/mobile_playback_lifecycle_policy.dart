import 'package:flutter/widgets.dart';

enum AndroidBackgroundPlaybackLifecycleAction {
  none,
  scheduleDelayedStart,
  startImmediately,
  restoreForeground,
}

class MobilePlaybackLifecyclePolicy {
  static AndroidBackgroundPlaybackLifecycleAction
      resolveAndroidBackgroundPlaybackAction({
    required AppLifecycleState state,
    required bool canUseBackgroundPlayback,
    required bool backgroundPlaybackActive,
    required bool isPipMode,
  }) {
    if (state == AppLifecycleState.resumed) {
      return backgroundPlaybackActive
          ? AndroidBackgroundPlaybackLifecycleAction.restoreForeground
          : AndroidBackgroundPlaybackLifecycleAction.none;
    }

    if (backgroundPlaybackActive) {
      return AndroidBackgroundPlaybackLifecycleAction.none;
    }

    if (!canUseBackgroundPlayback || isPipMode) {
      return AndroidBackgroundPlaybackLifecycleAction.none;
    }

    return switch (state) {
      AppLifecycleState.paused =>
        AndroidBackgroundPlaybackLifecycleAction.startImmediately,
      AppLifecycleState.inactive ||
      AppLifecycleState.hidden =>
        AndroidBackgroundPlaybackLifecycleAction.scheduleDelayedStart,
      AppLifecycleState.detached =>
        AndroidBackgroundPlaybackLifecycleAction.none,
      AppLifecycleState.resumed =>
        AndroidBackgroundPlaybackLifecycleAction.none,
    };
  }

  static bool shouldRememberAndroidBackgroundPlaybackIntent({
    required AppLifecycleState state,
    required bool isAndroid,
    required bool canUseBackgroundPlayback,
    required bool backgroundPlaybackActive,
    required bool isPipMode,
    required bool wasPlayingBeforeBackground,
  }) {
    if (!isAndroid ||
        !canUseBackgroundPlayback ||
        backgroundPlaybackActive ||
        isPipMode ||
        !wasPlayingBeforeBackground) {
      return false;
    }

    return state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused;
  }

  static bool shouldStartAndroidBackgroundPlayback({
    required bool adapterPlaying,
    required bool lastKnownPlaying,
    required bool rememberedPlaybackIntent,
  }) {
    return adapterPlaying || lastKnownPlaying || rememberedPlaybackIntent;
  }

  static bool shouldRememberIosForegroundResume({
    required AppLifecycleState state,
    required bool isIOS,
    required bool usesWebViewAdapter,
    required bool isPipMode,
    required bool wasPlayingBeforeBackground,
  }) {
    if (!isIOS ||
        !usesWebViewAdapter ||
        isPipMode ||
        !wasPlayingBeforeBackground) {
      return false;
    }

    return state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused;
  }

  static bool shouldAttemptIosForegroundResume({
    required AppLifecycleState state,
    required bool isIOS,
    required bool usesWebViewAdapter,
    required bool isPipMode,
    required bool pendingForegroundResume,
  }) {
    if (!isIOS ||
        !usesWebViewAdapter ||
        isPipMode ||
        !pendingForegroundResume) {
      return false;
    }

    return state == AppLifecycleState.resumed;
  }

  static bool shouldReloadIosForegroundPlayback({
    required bool isIOS,
    required bool usesWebViewAdapter,
    required bool isPipMode,
    required bool pendingForegroundResume,
    required Duration positionBeforeResume,
    required Duration positionAfterResumeGracePeriod,
    required bool isPlayingAfterResumeGracePeriod,
    required bool isBufferingAfterResumeGracePeriod,
  }) {
    if (!isIOS ||
        !usesWebViewAdapter ||
        isPipMode ||
        !pendingForegroundResume) {
      return false;
    }

    final advancedEnough =
        positionAfterResumeGracePeriod - positionBeforeResume >=
            const Duration(milliseconds: 250);
    if (advancedEnough) {
      return false;
    }

    return isBufferingAfterResumeGracePeriod ||
        !isPlayingAfterResumeGracePeriod;
  }
}
