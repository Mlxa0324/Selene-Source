import 'dart:io' show Platform;

enum MobileNetworkPlayerBackend {
  webView,
  mediaKit,
}

class PlayerBackendConfig {
  PlayerBackendConfig._();

  // 手动开关：iOS 在线播放后端。
  // 可选：MobileNetworkPlayerBackend.mediaKit / MobileNetworkPlayerBackend.webView
  // 当前默认切到 media_kit，优先保证 iOS 高倍速与 PiP 等原生播放能力。
  static const MobileNetworkPlayerBackend iosNetworkBackend =
      MobileNetworkPlayerBackend.mediaKit;

  // 手动开关：Android 在线播放后端。
  // 目前默认仍保持 WebView，避免影响现有行为。
  static const MobileNetworkPlayerBackend androidNetworkBackend =
      MobileNetworkPlayerBackend.webView;

  static MobileNetworkPlayerBackend get currentMobileNetworkBackend {
    if (Platform.isIOS) return iosNetworkBackend;
    if (Platform.isAndroid) return androidNetworkBackend;
    return MobileNetworkPlayerBackend.webView;
  }

  static bool get useMediaKitForMobileNetworkPlayback {
    if (!(Platform.isIOS || Platform.isAndroid)) {
      return false;
    }
    return currentMobileNetworkBackend == MobileNetworkPlayerBackend.mediaKit;
  }

  static bool get shouldInitializeMediaKit {
    if (Platform.isWindows || Platform.isMacOS) {
      return true;
    }
    return useMediaKitForMobileNetworkPlayback;
  }
}
