import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let orientationChannelName = "selene/orientation"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let orientationChannel = FlutterMethodChannel(
        name: orientationChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      orientationChannel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getCurrentInterfaceOrientation":
          result(self?.resolveCurrentInterfaceOrientation() ?? "unknown")
        case "getSystemAutoRotateEnabled":
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    // 配置音频会话以支持后台播放和 PiP
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .moviePlayback, options: [])
      try audioSession.setActive(true)
    } catch {
      print("Failed to set audio session category: \(error)")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func resolveCurrentInterfaceOrientation() -> String {
    let sceneOrientation =
      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first(where: { $0.activationState == .foregroundActive })?
        .interfaceOrientation
      ?? window?.windowScene?.interfaceOrientation
      ?? .unknown

    switch sceneOrientation {
    case .portrait:
      return "portraitUp"
    case .portraitUpsideDown:
      return "portraitDown"
    case .landscapeLeft:
      // UIInterfaceOrientation 与 Flutter 的 DeviceOrientation 在这里保持同名映射，
      // 否则点击播放器锁定时会被误判到对侧横屏，触发 180 度旋转后再锁住。
      return "landscapeLeft"
    case .landscapeRight:
      return "landscapeRight"
    default:
      return "unknown"
    }
  }
}
