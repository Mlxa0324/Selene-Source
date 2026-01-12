[根目录](../CLAUDE.md) > **android**

---

# Android 原生模块

## 模块职责

Android 原生模块负责 Android 平台特定的配置和功能实现，包括应用打包、权限配置、原生插件集成等。

---

## 入口与启动

**入口文件：**
- `app/src/main/kotlin/org/moontechlab/selene/MainActivity.kt`

**启动流程：**
1. Android 系统启动 `MainActivity`
2. `MainActivity` 继承 `FlutterActivity`，自动加载 Flutter 引擎
3. Flutter 引擎执行 `lib/main.dart`

---

## 对外接口

### MainActivity

```kotlin
package org.moontechlab.selene

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

**说明：**
- 标准 Flutter Activity，无自定义逻辑
- 所有 Flutter 插件通过 `GeneratedPluginRegistrant` 自动注册

---

## 关键依赖与配置

### Gradle 配置

**build.gradle.kts (项目级)：**
- 仓库：Google、Maven Central
- 构建目录：自定义到 `../../build`

**build.gradle.kts (应用级)：**
- 应用 ID：`org.moontechlab.selene`
- 最低 SDK：由 Flutter 配置决定
- 目标 SDK：由 Flutter 配置决定
- 编译 SDK：由 Flutter 配置决定
- NDK 版本：29.0.14206865
- Kotlin 版本：1.9+
- Java 版本：11

### 签名配置

**发布签名：**
- 配置文件：`android/key.properties`（不在版本控制中）
- 如果签名文件不存在，使用 debug 签名

**ProGuard 配置：**
- 启用代码混淆和资源压缩
- 配置文件：`proguard-rules.pro`

### AndroidManifest.xml

**权限：**
- 网络访问：`INTERNET`
- 网络状态：`ACCESS_NETWORK_STATE`
- 外部存储：`WRITE_EXTERNAL_STORAGE`（可选）

**配置：**
- 网络安全配置：`network_security_config.xml`（允许明文 HTTP）
- 应用图标：`launcher_icon`
- 启动画面：`launch_background.xml`

---

## 数据模型

无特定数据模型（使用 Flutter 层的模型）

---

## 测试与质量

**当前状态：** 无 Android 原生测试

**建议测试：**
1. **Instrumentation 测试**：测试 Activity 启动
2. **权限测试**：验证运行时权限请求

---

## 常见问题 (FAQ)

### Q1: 如何添加 Android 原生功能？
1. 在 `MainActivity.kt` 中添加 MethodChannel
2. 在 Flutter 层调用 MethodChannel
3. 处理原生代码逻辑

### Q2: 如何配置应用签名？
1. 生成 keystore 文件
2. 创建 `android/key.properties` 文件
3. 配置 storeFile、storePassword、keyAlias、keyPassword

### Q3: 如何修改应用图标？
- 使用 `flutter_launcher_icons` 包自动生成
- 或手动替换 `res/mipmap-*/launcher_icon.png`

---

## 相关文件清单

### 核心文件
- `app/src/main/kotlin/org/moontechlab/selene/MainActivity.kt` (入口)
- `app/build.gradle.kts` (应用构建配置)
- `build.gradle.kts` (项目构建配置)
- `settings.gradle.kts` (项目设置)

### 配置文件
- `app/src/main/AndroidManifest.xml` (应用清单)
- `app/src/debug/AndroidManifest.xml` (调试配置)
- `app/src/profile/AndroidManifest.xml` (性能分析配置)
- `app/proguard-rules.pro` (混淆规则)
- `app/src/main/res/xml/network_security_config.xml` (网络安全)

### 资源文件
- `app/src/main/res/drawable*/launch_background.xml` (启动画面)
- `app/src/main/res/mipmap-*/launcher_icon.png` (应用图标)
- `app/src/main/res/values/styles.xml` (样式)

### 文件统计
- Kotlin 文件：1
- Gradle 配置：3
- XML 配置：约 10 个

---

## 变更记录 (Changelog)

### 2026-01-11
- 初始化模块文档
- 记录 Gradle 配置和签名策略
- 识别核心配置文件

---

**模块版本：** 1.0.0
**最后更新：** 2026-01-11
