import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let orientationChannelName = "selene/orientation"
  private let physicalOrientationChannelName = "selene/physical_orientation"
  private var physicalOrientationStreamHandler: PhysicalOrientationStreamHandler?

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

      let physicalOrientationChannel = FlutterEventChannel(
        name: physicalOrientationChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      let streamHandler = PhysicalOrientationStreamHandler()
      physicalOrientationStreamHandler = streamHandler
      physicalOrientationChannel.setStreamHandler(streamHandler)
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

/// 监听 iOS 物理设备方向，用于全屏播放器横屏侧切换提示。
private final class PhysicalOrientationStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var lastOrientation: String?

  /// 开始监听物理方向变化。
  ///
  /// - Parameters:
  ///   - arguments: Flutter 侧传入的监听参数，当前未使用。
  ///   - events: Flutter 事件回调。
  /// - Returns: 监听启动失败时返回 FlutterError。
  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    lastOrientation = nil
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDeviceOrientationChanged),
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
    emitOrientation(UIDevice.current.orientation)
    return nil
  }

  /// 取消监听物理方向变化。
  ///
  /// - Parameter arguments: Flutter 侧传入的取消参数，当前未使用。
  /// - Returns: 取消失败时返回 FlutterError。
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(
      self,
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
    UIDevice.current.endGeneratingDeviceOrientationNotifications()
    eventSink = nil
    lastOrientation = nil
    return nil
  }

  /// 收到设备物理方向变化通知。
  @objc private func handleDeviceOrientationChanged() {
    emitOrientation(UIDevice.current.orientation)
  }

  /// 向 Flutter 推送去重后的物理方向。
  ///
  /// - Parameter orientation: iOS 设备物理方向。
  private func emitOrientation(_ orientation: UIDeviceOrientation) {
    guard let rawOrientation = resolvePhysicalDeviceOrientation(orientation) else {
      return
    }
    if rawOrientation == lastOrientation {
      return
    }
    lastOrientation = rawOrientation
    eventSink?(rawOrientation)
  }

  /// 将 iOS 物理方向映射到 Flutter 播放器方向枚举名称。
  ///
  /// - Parameter orientation: iOS 设备物理方向。
  /// - Returns: Flutter 侧 MobileInterfaceOrientation 名称。
  private func resolvePhysicalDeviceOrientation(
    _ orientation: UIDeviceOrientation
  ) -> String? {
    switch orientation {
    case .portrait:
      return "portraitUp"
    case .portraitUpsideDown:
      return "portraitDown"
    case .landscapeLeft:
      // UIDeviceOrientation 的横屏左右与界面方向相反，这里转为 Flutter 方向。
      return "landscapeRight"
    case .landscapeRight:
      return "landscapeLeft"
    default:
      return nil
    }
  }
}
