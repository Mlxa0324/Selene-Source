# re-android

Selene Kotlin 原生 Android TV 重建工程。

当前首期已经落地的能力：

- `app-tv`：TV 应用壳、顶级导航、隐藏播放器路由、Leanback 启动入口
- `core-design`：TV 设计标尺、主题令牌、焦点卡片、主线程与播放/IO 线程调度拆分
- `core-network` + `core-data`：服务端接口 DTO、会话 Cookie、设置存储、首页/搜索/详情/播放仓库
- `core-player-api`：统一播放器协议、播放快照、内核枚举与状态模型
- `core-player-exo`：ExoPlayer 主播放内核
- `core-player-webview`：WebView 兜底内核与 JS Bridge
- `feature-tv-*`：首页、搜索、详情、播放历史、收藏夹、设置、直播、全屏播放器壳
- `core-benchmark`：播放器基准记录能力

## 当前交付范围

- 默认使用 `WebView` 播放，优先对齐 Flutter TV 的兼容链路
- 全屏底部菜单支持 `其它 -> 内核切换`
- 切换到 `WebView` 后会基于播放快照恢复集数、线路与进度
- `直播` 提供频道列表、当前节目和节目单页面状态
- 暂未接入 `DLNA` 与 `本地离线`

## 模块结构

```text
re-android/
├── app-tv
├── core-benchmark
├── core-data
├── core-design
├── core-network
├── core-player-api
├── core-player-exo
├── core-player-webview
├── feature-tv-detail
├── feature-tv-favorites
├── feature-tv-history
├── feature-tv-home
├── feature-tv-live
├── feature-tv-player
├── feature-tv-search
└── feature-tv-settings
```

## 验证命令

在 `re-android/` 目录执行：

```bash
./gradlew testDebugUnitTest
./gradlew :feature-tv-player:connectedDebugAndroidTest
./gradlew lintDebug
```

如需显式指定 Android SDK：

```bash
ANDROID_HOME=/Users/your-name/Library/Android/sdk \
ANDROID_SDK_ROOT=/Users/your-name/Library/Android/sdk \
./gradlew testDebugUnitTest
```

## 说明

- Android TV 清单已补齐 `LEANBACK_LAUNCHER`、`banner`、`icon` 与触摸屏兼容声明
- 当前 UI 和数据链路已对齐 Flutter TV 端首期行为，迭代工作按模块验收推进
