# Journal - Lx (Part 1)

> AI development session journal
> Started: 2026-05-31

---



## Session 1: Kotlin TV UI 子任务推进

**Date**: 2026-05-31
**Task**: Kotlin TV UI 子任务推进
**Branch**: `tvtv`

### Summary

完成 Kotlin TV 首页视频库与详情播放器复刻子任务，补充对应测试并通过目标 Gradle 校验。

### Main Changes

- 给 `app-tv` Manifest 补充 `android.permission.INTERNET`。
- 通过 manifest placeholder 让 debug 包允许本地 HTTP 后台，release 包默认关闭明文流量。
- 更新 TV 网络层规格，记录原生 TV 启动依赖 Manifest 网络权限。
- 归档 `05-31-fix-kotlin-tv-launch-crash` 任务。

### Git Commits

| Hash | Message |
|------|---------|
| `de02675` | (see git log) |
| `75ade60` | (see git log) |

### Testing

- [OK] `./re-android/gradlew -p re-android :app-tv:testDebugUnitTest :app-tv:lintDebug`
- [OK] `./re-android/gradlew -p re-android :app-tv:processReleaseManifest`
- [OK] `./re-android/gradlew -p re-android :app-tv:installDebug`
- [OK] `adb shell am start -n org.moontechlab.selene.tv.app/.MainActivity`
- [OK] 启动后 `adb logcat` 未出现 `AndroidRuntime`、`FATAL EXCEPTION`、`missing INTERNET` 或 `Permission denied`。

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 2: Kotlin TV 功能页验收

**Date**: 2026-05-31
**Task**: Kotlin TV 功能页验收
**Branch**: `tvtv`

### Summary

完成搜索、历史、收藏、设置、直播和弹幕入口验收，清理 re-android 用户可见 placeholder，并通过相关单测、lint、diff 检查。

### Main Changes

- 保留 `4c463ef` 中的 Flutter TV 续播兼容修复：详情页和全屏页在真实进度回调后确认续播 seek 是否生效，并限次补偿。
- 因投影仪真机无法连接，停止继续采集真机对比日志，将未完成的真机验收项标记为放弃并归档任务。

### Git Commits

| Hash | Message |
|------|---------|
| `c001601` | (see git log) |
| `011594f` | (see git log) |

### Testing

- [OK] `flutter test test/tv_app/tv_video_detail_screen_test.dart`
- [OK] `flutter test test/tv_app/tv_fullscreen_player_screen_test.dart`
- [OK] `flutter analyze lib/tv_app/screens/tv_video_detail_screen.dart lib/tv_app/screens/tv_fullscreen_player_screen.dart lib/tv_app/services/tv_play_record_service.dart`

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 3: Kotlin TV 本地后台网关配置

**Date**: 2026-05-31
**Task**: Kotlin TV 本地后台网关配置
**Branch**: `tvtv`

### Summary

新增 re-android 本地 git-ignore 后台配置，接入 BuildConfig、登录 Cookie 会话、Retrofit 网关工厂和 app-tv 首页真实后台加载，并补充相关测试与 TV 规格。

### Main Changes

- Raised the fullscreen episode group label font size from 15 to 17 while keeping normal secondary menu buttons at 16.
- Added a stable key for the fullscreen bottom total-time slot so widget tests can assert the progress chrome without matching unrelated time text.
- Updated TV mode spec and task PRD to document the episode-group label exception.

### Git Commits

| Hash | Message |
|------|---------|
| `19f5599` | (see git log) |
| `df990a5` | (see git log) |

### Testing

- [OK] `flutter analyze lib/tv_app/screens/tv_fullscreen_player_screen.dart test/tv_app/tv_fullscreen_player_screen_test.dart`
- [OK] `flutter test test/tv_app/tv_fullscreen_player_screen_test.dart` (61/61)
- [OK] `git diff --check`

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 4: 修复 Kotlin TV 启动闪退

**Date**: 2026-05-31
**Task**: 修复 Kotlin TV 启动闪退
**Branch**: `tvtv`

### Summary

定位 TV 壳启动闪退为缺少 INTERNET 权限导致 OkHttp 线程 SecurityException；补充网络权限、debug 本地 HTTP 明文策略、release 关闭明文，并完成单测、lint、安装启动验证。

### Main Changes

- 详情页选集分组获焦只保留焦点记忆和横向滚动定位，确认键才切换分组。
- 全屏播放列表分组获焦不再刷新当前播放列表分组，上键回到已确认分组的选集。
- 保留选集卡片左右跨组自动切换，并同步 TV 模式焦点契约。

### Git Commits

| Hash | Message |
|------|---------|
| `efdad40` | (see git log) |

### Testing

- [OK] `flutter analyze lib/tv_app/screens/tv_fullscreen_player_screen.dart lib/tv_app/screens/tv_video_detail_screen.dart lib/widgets/video_player_widget.dart test/tv_app/tv_fullscreen_player_screen_test.dart test/tv_app/tv_video_detail_screen_test.dart test/widgets/video_player_widget_preload_config_test.dart`
- [OK] `flutter test test/tv_app/tv_video_detail_screen_test.dart`
- [OK] `flutter test test/tv_app/tv_fullscreen_player_screen_test.dart`
- [OK] `flutter test test/widgets/video_player_widget_preload_config_test.dart`
- [OK] `git diff --check`

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 5: 修复 TV 分类筛选与焦点记忆

**Date**: 2026-06-01
**Task**: 修复 TV 分类筛选与焦点记忆
**Branch**: `tvtv`

### Summary

完成分类筛选视觉就近焦点，以及详情页和全屏播放页横向列表焦点记忆修复

### Main Changes

- `SeleneTvNetworkClient.login` 将 `IOException` 转换为 TV 首页可读诊断，并在域名最终连接到不同地址时提示实际失败目标。
- 登录非成功响应区分 401、PassNAT 节点页、普通 HTML 错误页和其他 HTTP 状态，避免把 API 入口错误误判成旧 APK 或单纯断网。
- `TvHomeRepository.loadHome` 隔离继续观看、dashboard 和兜底分类失败，单个接口异常不再拖垮整个首页。
- 补充 Trellis 任务与 Native Android TV Local Gateway 规格，记录本次 ivy3004 域名实际落到 `192.168.31.28:9000` 的排查结论。

### Git Commits

| Hash | Message |
|------|---------|
| `9599a94` | (see git log) |
| `c29e979` | (see git log) |

### Testing

- [OK] `./gradlew :core-network:testDebugUnitTest :core-data:testDebugUnitTest`
- [OK] `./gradlew :app-tv:assembleDebug`
- [OK] `adb install -r app-tv/build/outputs/apk/debug/app-tv-debug.apk`
- [OK] 模拟器重启应用截图确认首页显示配置域名 `http://ivy3004.s.odn.cc` 和实际失败目标 `192.168.31.28:9000`。

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 6: 投影仪续播调查任务归档

**Date**: 2026-06-01
**Task**: 投影仪续播调查任务归档
**Branch**: `tvtv`

### Summary

修复 Flutter TV 续播 seek 在低端 Android WebView 上可能被首次吞掉的问题；因投影仪真机无法连接，停止模拟器与投影仪日志对比并归档任务。

### Main Changes

- Rebuilt Kotlin TV detail state around exact-source and title-fallback loaders.
- Added incremental source merge, resume-target waiting, completed empty state, and playback request derivation.
- Wired repository/container loaders and regression tests for the new contract.
- Documented the Kotlin TV detail state-machine contract in `.trellis/spec/frontend/tv-mode.md`.

### Git Commits

| Hash | Message |
|------|---------|
| `4c463ef` | (see git log) |

### Testing

- [OK] `./re-android/gradlew -p re-android :feature-tv-detail:testDebugUnitTest :core-data:testDebugUnitTest :app-tv:testDebugUnitTest`
- [OK] `git diff --check -- <Phase 1 files>`

### Status

[OK] **Completed**

### Next Steps

- Start `06-18-rewrite-tv-detail-ui-focus` for the detail UI and focus graph rewrite.


## Session 7: 完成搜索页详情复用搜索会话

**Date**: 2026-06-02
**Task**: 完成搜索页详情复用搜索会话
**Branch**: `tvtv`

### Summary

完成 TV 搜索页进入详情页时复用同片名候选源与共享 SSE 搜索会话，避免详情页重复按标题补源，并补充空态与回归测试。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `083b58b` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 8: 分析 Flutter TV 详情页首播卡顿因素

**Date**: 2026-06-02
**Task**: 分析 Flutter TV 详情页首播卡顿因素
**Branch**: `tvtv`

### Summary

完成 Flutter TV 详情页进入卡顿因素分析，确认 WebView 首次初始化、异步回调叠加与较重 UI 为主要共因，并把首播门闩与轻量预览占位规则补充到 TV spec。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `d24cccf` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 9: 粗对齐 Kotlin TV 页面壳样式

**Date**: 2026-06-02
**Task**: 粗对齐 Kotlin TV 页面壳样式
**Branch**: `tvtv`

### Summary

完成 Kotlin TV 首页、分类、详情、播放器的第一轮样式粗对齐，统一 token、导航、海报卡片和页面壳；补首页 dashboard 失败兜底与相关单元测试，并通过 Kotlin 相关模块单元测试。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `7fedcac` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 10: 放大全屏选集分组文字

**Date**: 2026-06-05
**Task**: 放大全屏选集分组文字
**Branch**: `tvtv`

### Summary

将 TV 全屏播放器底部选集分组标签字号提升到 17，保留普通二级菜单 16 号；补充菜单字号与暂停进度槽测试，并同步 TV 模式规范。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `b33df9a` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 11: 调整 TV 选集分组焦点切换

**Date**: 2026-06-06
**Task**: 调整 TV 选集分组焦点切换
**Branch**: `tvtv`

### Summary

实现详情页和全屏播放选集分组确认键切换；保留集数左右跨组自动切换；完成 TV 焦点、全屏播放器和预加载相关验证。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `adc88bc` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 12: 修复Kotlin TV首页后台诊断

**Date**: 2026-06-14
**Task**: 修复Kotlin TV首页后台诊断
**Branch**: `tvtv`

### Summary

修复Kotlin TV首页后台配置后无数据链路：网络登录错误区分连接失败、PassNAT/HTML页面和实际失败目标；首页仓库隔离继续观看与兜底分类失败；补充单测、构建和模拟器截图验证。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `9b7e01e` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 13: 重做 Kotlin TV 详情状态机数据链路

**Date**: 2026-06-18
**Task**: 重做 Kotlin TV 详情状态机数据链路
**Branch**: `tvtv`

### Summary

按 Flutter TV 逻辑重做 Kotlin TV 详情页状态机：拆分精确源和标题补源双路加载，支持增量首播、续播目标等待、完成空态、播放请求派生，并补充仓库/容器接线测试和 TV 模式规格。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `4a78535` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 14: 重做 Kotlin TV 详情 UI 焦点图

**Date**: 2026-06-18
**Task**: 重做 Kotlin TV 详情 UI 焦点图
**Branch**: `tvtv`

### Summary

完成详情页第二阶段：重写 Kotlin TV 详情页 UI 结构，新增展示/焦点策略测试，接入线路、选集、分组横向获焦滚动，并沉淀 tv-mode 规范。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `1e2f38c` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete
