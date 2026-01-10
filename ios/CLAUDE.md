[根目录](../CLAUDE.md) > **ios**

---

# iOS 原生模块

## 模块职责

iOS 原生模块负责 iOS 平台特定的配置和功能实现，包括应用打包、权限配置、音频会话管理、画中画（PiP）支持等。

---

## 入口与启动

**入口文件：**
- `Runner/AppDelegate.swift`

**启动流程：**
1. iOS 系统启动 `AppDelegate`
2. `didFinishLaunchingWithOptions` 方法配置音频会话
3. 注册 Flutter 插件
4. 启动 Flutter 引擎

---

## 对外接口

### AppDelegate

```swift
import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

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
}
```

**功能：**
- 配置音频会话为 `.playback` 类别，支持后台播放
- 设置播放模式为 `.moviePlayback`，优化视频播放
- 激活音频会话

---

## 关键依赖与配置

### Xcode 项目配置

**Runner.xcodeproj：**
- 部署目标：iOS 12.0+
- Swift 版本：5.0+
- 团队签名：需要配置开发者账号

### Podfile

**依赖管理：**
```ruby
platform :ios, '12.0'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

**说明：**
- 使用 CocoaPods 管理 iOS 依赖
- 自动安装所有 Flutter 插件的 iOS 依赖

### Info.plist 配置

**权限声明：**
- `NSCameraUsageDescription`：相机权限（如需）
- `NSMicrophoneUsageDescription`：麦克风权限（如需）
- `NSPhotoLibraryUsageDescription`：相册权限（如需）
- `NSAppTransportSecurity`：允许 HTTP 请求

**后台模式：**
- `audio`：后台音频播放
- `fetch`：后台数据获取（可选）

### 音频会话配置

**类别：** `.playback`
- 支持后台播放
- 自动处理中断（来电、闹钟等）
- 支持远程控制（锁屏控制）

**模式：** `.moviePlayback`
- 优化视频播放音质
- 自动调整音频路由

---

## 数据模型

无特定数据模型（使用 Flutter 层的模型）

---

## 测试与质量

**当前状态：** 无 iOS 原生测试

**建议测试：**
1. **XCTest**：测试 AppDelegate 初始化
2. **UI 测试**：测试应用启动流程
3. **音频会话测试**：验证后台播放和 PiP

---

## 常见问题 (FAQ)

### Q1: 如何添加 iOS 原生功能？
1. 在 `AppDelegate.swift` 中添加 FlutterMethodChannel
2. 在 Flutter 层调用 MethodChannel
3. 处理原生代码逻辑

### Q2: 如何配置应用签名？
1. 在 Xcode 中打开 `Runner.xcworkspace`
2. 选择 Runner 目标
3. 在 Signing & Capabilities 中配置团队和证书

### Q3: 如何支持画中画（PiP）？
- 音频会话已配置为 `.playback` 和 `.moviePlayback`
- 使用 `pip` 插件（已在 `pubspec.yaml` 中配置）
- 确保视频播放器支持 PiP

### Q4: 为什么后台播放不工作？
- 检查 Info.plist 中是否启用了 `audio` 后台模式
- 确认音频会话配置正确
- 验证音频会话是否激活

---

## 相关文件清单

### 核心文件
- `Runner/AppDelegate.swift` (应用入口)
- `Runner.xcodeproj/project.pbxproj` (Xcode 项目配置)
- `Podfile` (CocoaPods 依赖)
- `Podfile.lock` (依赖锁定)

### 配置文件
- `Runner/Info.plist` (应用配置)
- `Flutter/Debug.xcconfig` (调试配置)
- `Flutter/Release.xcconfig` (发布配置)
- `ExportOptions.plist` (导出配置)

### 资源文件
- `Runner/Assets.xcassets/AppIcon.appiconset/` (应用图标)
- `Runner/Assets.xcassets/LaunchImage.imageset/` (启动图片)

### Xcode 工作空间
- `Runner.xcworkspace/` (Xcode 工作空间)
- `Runner.xcodeproj/` (Xcode 项目)

### 文件统计
- Swift 文件：1
- Xcode 配置：多个
- 资源文件：约 20 个图标文件

---

## 变更记录 (Changelog)

### 2026-01-11
- 初始化模块文档
- 记录音频会话配置
- 识别 PiP 支持配置

---

**模块版本：** 1.0.0
**最后更新：** 2026-01-11
