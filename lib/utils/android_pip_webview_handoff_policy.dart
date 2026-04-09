import 'package:flutter/widgets.dart';

abstract final class AndroidPipWebViewHandoffPolicy {
  static bool shouldArmForPip({
    required bool isAndroid,
    required bool screenOffPlaybackEnabled,
    required bool usesWebViewAdapter,
    required bool isLocal,
    required bool canUseNativeBackgroundPlayback,
    required bool backgroundPlaybackActive,
    required bool pipNativeTransitioning,
  }) {
    return isAndroid &&
        screenOffPlaybackEnabled &&
        usesWebViewAdapter &&
        !isLocal &&
        canUseNativeBackgroundPlayback &&
        !backgroundPlaybackActive &&
        !pipNativeTransitioning;
  }

  static bool shouldPrepareNativePlaybackForPip({
    required bool isAndroid,
    required bool shouldArmForPip,
  }) {
    return isAndroid && !shouldArmForPip;
  }

  static bool shouldArmBackgroundHandoffOnPipStarted({
    required bool isAndroid,
    required bool canUseHandoff,
    required bool handoffArmed,
  }) {
    return isAndroid && canUseHandoff && !handoffArmed;
  }

  static bool shouldStartBackgroundHandoffTimer({
    required AppLifecycleState state,
    required bool isAndroid,
    required bool isPipMode,
    required bool handoffArmed,
  }) {
    if (!isAndroid || !isPipMode || !handoffArmed) {
      return false;
    }
    return state != AppLifecycleState.resumed;
  }

  static bool shouldCancelBackgroundHandoff({
    required AppLifecycleState state,
    required bool isAndroid,
    required bool isPipMode,
    required bool handoffArmed,
  }) {
    if (!isAndroid || !handoffArmed) {
      return false;
    }
    return state == AppLifecycleState.resumed || !isPipMode;
  }

  static bool shouldExecuteBackgroundHandoff({
    required bool mounted,
    required bool isPipMode,
    required bool handoffArmed,
    required bool canUseHandoff,
    required AppLifecycleState lastLifecycleState,
  }) {
    return mounted &&
        isPipMode &&
        handoffArmed &&
        canUseHandoff &&
        lastLifecycleState != AppLifecycleState.resumed;
  }
}
