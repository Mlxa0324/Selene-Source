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

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `c001601` | (see git log) |
| `011594f` | (see git log) |

### Testing

- [OK] (Add test results)

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

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `19f5599` | (see git log) |
| `df990a5` | (see git log) |

### Testing

- [OK] (Add test results)

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

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `efdad40` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete
