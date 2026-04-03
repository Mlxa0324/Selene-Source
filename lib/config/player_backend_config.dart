import 'dart:io' show Platform;

enum MobileNetworkPlayerBackend {
  webView,
  mediaKit,
}

class PlayerBackendConfig {
  PlayerBackendConfig._();

  // 手动开关：iOS 在线播放后端。
  // 可选：MobileNetworkPlayerBackend.mediaKit / MobileNetworkPlayerBackend.webView
  // 当前默认切到 webView
  static const MobileNetworkPlayerBackend iosNetworkBackend =
      MobileNetworkPlayerBackend.webView;

  // 手动开关：Android 在线播放后端。
  // 目前默认仍保持 WebView，避免影响现有行为。
  static const MobileNetworkPlayerBackend androidNetworkBackend =
      MobileNetworkPlayerBackend.webView;

  static MobileNetworkPlayerBackend resolveMobileNetworkBackendForPlatform({
    required bool isAndroid,
    required bool isIOS,
    bool preferAndroidScreenOffPlayback = false,
  }) {
    if (isIOS) return iosNetworkBackend;
    if (isAndroid) return androidNetworkBackend;
    return MobileNetworkPlayerBackend.webView;
  }

  static bool shouldUseMediaKitForMobileNetworkPlaybackForPlatform({
    required bool isAndroid,
    required bool isIOS,
    bool preferAndroidScreenOffPlayback = false,
  }) {
    if (!(isIOS || isAndroid)) {
      return false;
    }
    return resolveMobileNetworkBackendForPlatform(
          isAndroid: isAndroid,
          isIOS: isIOS,
          preferAndroidScreenOffPlayback: preferAndroidScreenOffPlayback,
        ) ==
        MobileNetworkPlayerBackend.mediaKit;
  }

  static bool shouldInitializeMediaKitForPlatform({
    required bool isWindows,
    required bool isMacOS,
    required bool isAndroid,
    required bool isIOS,
    bool preferAndroidScreenOffPlayback = false,
  }) {
    if (isWindows || isMacOS) {
      return true;
    }
    return shouldUseMediaKitForMobileNetworkPlaybackForPlatform(
      isAndroid: isAndroid,
      isIOS: isIOS,
      preferAndroidScreenOffPlayback: preferAndroidScreenOffPlayback,
    );
  }

  static MobileNetworkPlayerBackend get currentMobileNetworkBackend {
    return resolveMobileNetworkBackendForPlatform(
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
    );
  }

  static bool get useMediaKitForMobileNetworkPlayback {
    return shouldUseMediaKitForMobileNetworkPlaybackForPlatform(
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
    );
  }

  static bool get shouldInitializeMediaKit {
    return shouldInitializeMediaKitForPlatform(
      isWindows: Platform.isWindows,
      isMacOS: Platform.isMacOS,
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
    );
  }
}
