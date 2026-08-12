# 优化 Android WebView HLS 拖动响应速度

## 背景

同一个 CMS 站的 HLS 源,在本 App(Android)里用 WebView + hls.js 播放时,拖动进度条后的画面恢复明显比在 CMS 站直接播放慢(用户反馈"慢一倍")。

经代码分析,根因不在网络,而在 WebView 注入的 hls.js 配置与每次 seek 触发的副作用:

- `lowLatencyMode: true` 全局开启,削弱 `maxBufferLength` 的实际效果,seek 后前向缓冲填得慢。
- `seekBoostEnabled` 在每次 seek 时调用 `warmupByConcurrentFetch`,并发拉取同一目标分片,与 hls.js 自身的真实请求**抢同一台 CDN 的同一分片**,在移动网络下显著拉长 seek 恢复时间。
- `seekBoostEnabled` 把 `maxFragLookUpTolerance=0.1` / `maxBufferHole=0.1` 压到 100ms,任何小空洞都会触发重新加载。
- `<video>` 元素未显式设置 `preload`,WebView 默认走 `metadata`,seek 时前向几乎无缓冲。

iOS 路线本次不动。`MediaKitAdapter` 不参与本次改动,也不作为兜底(Android 已确认不切 media_kit)。

## 目标

在不更换播放后端(继续用 WebView + hls.js)的前提下,显著缩短 Android 上拖动进度条后的画面恢复时间,使其接近同一 CMS 源在浏览器(或 CMS 站本身)中的体感。

## 范围

### 平台范围

- **仅 Android**(Platform.isAndroid)。
- iOS WebView 路线、桌面 media_kit、移动端 media_kit 兜底逻辑保持不变。

### 代码范围

主要改动集中在:

- `lib/widgets/player_adapter.dart`
  - hls.js `config` 构造段(当前 `lowLatencyMode: true`、seekBoost 容差段)
  - `fastSeekTo` JS 实现(当前每次 seek 调用 `hls.startLoad` + `warmupByConcurrentFetch`)
  - `warmupByConcurrentFetch` 调用时机
  - `<video>` 元素 HTML(显式 `preload`)

不涉及:

- `lib/config/player_backend_config.dart` 后端路由(Android 已是 webView)
- `lib/widgets/video_player_widget.dart` 后端选择逻辑
- 弹幕、选集、PiP、定时器、投屏等业务功能
- iOS 专用代码路径(`__iosPitchConfigured`、`setIOSPitchPreservation`、`beginRateChangeBufferingSuppression` 等)

## 需求

### R1 关闭 hls.js 低延迟模式(Android)

Android 在线播放路径下,hls.js `config.lowLatencyMode` 不再无条件为 `true`。点播场景使用默认(false);若后续有直播需求再单独区分。

### R2 取消 seekBoost 的并发预热抢占

每次 `fastSeekTo` 触发的 `warmupByConcurrentFetch(sec)` 在 Android 在线播放路径下不再执行,避免与 hls.js 的真实分片请求抢带宽。`warmupByConcurrentFetch` 函数本身可保留(供其它路径或未来验证使用),但 `fastSeekTo` 不再调用它。

### R3 放宽 seekBoost 的紧容差

`maxFragLookUpTolerance=0.1` 与 `maxBufferHole=0.1` 这两项紧容差配置删除(回到 hls.js 默认),避免小空洞频繁触发分片重新加载。`nudgeMaxRetry=1` 是否保留按测试结果决定,默认建议保留。

### R4 显式 `<video preload="auto">`

`<video id="player" playsinline>` 改为 `<video id="player" playsinline preload="auto">`,让浏览器为 seek 提前持有更多前向缓冲。

### R5 `hls.startLoad(sec)` 调用保留性评估

`fastSeekTo` 里 `window.hlsInstance.startLoad(sec)` 这一句:保留与否,取决于实测。`startLoad(sec)` 会让 hls.js 从指定位置继续加载,某些场景能加速 seek;但它也会强制重新计算加载位置。在 R1+R2+R3 之后再测,若不再带来正收益则删除,若仍有正收益则保留。

### R6 iOS 路径不回归

所有改动必须保证 iOS 在线播放路径上的 hls.js 行为与现状一致。具体做法可以是:
- 用 UA 判定在 JS 侧分支,或
- 用 Dart 侧构造 HTML 时按 `Platform.isAndroid` 注入不同参数。

哪种更易维护由 design 阶段决定,但**最终验收必须验证 iOS 不回归**。

## 验收标准

- [ ] Android 上,同一 CMS 源,在播放中途分别执行 `+30s / +90s / +180s` 三档 seek,每档 5 次:
  - "画面恢复时间"(从松手到画面再次推进)平均值显著低于改动前(目标:至少缩短 30%,以同一设备同一网络下改动前后实测对比为准)。
  - 极端个案无明显恶化(最大值不上升超过 20%)。
- [ ] iOS 上同一 CMS 源执行相同 seek 用例,iOS 的画面恢复时间与改动前基本一致(波动 ≤ 10%,以排除网络抖动)。
- [ ] 长视频(≥ 30 min)连续播放 10 分钟后执行 seek,行为与短时间播放后 seek 一致,无"长时间播放后 seek 变慢"的回归。
- [ ] 倍速播放(2x)切换、暂停 / 恢复、片头片尾跳过等业务功能不受影响。
- [ ] 网速显示(`network_speed` 事件)、缓存区间上报(`cached_ranges` 事件)正常工作。
- [ ] `flutter analyze` 无新增告警;现有相关测试(player_adapter_webview_preload_test、mobile_player_controls_seek_test 等)通过或按改动同步更新。

## 验证方法

- 主观验证:真机 Android 拖动进度条,与改动前对比体感。
- 客观验证:使用项目内隐藏的 player benchmark 页(参见 `docs/superpowers/specs/2026-03-30-player-backend-seek-benchmark-design.md`)在 Android 上对比改动前后的 `position_settle_ms` 与 `buffering_clear_ms`。
- 取数基线:同一设备、同一 Wi-Fi、同一 CMS 源、同一锚点(240s)、同一组左跳场景(10s/30s/90s/180s)。

## 非目标

- 不优化 iOS。
- 不引入或调整 media_kit 在 Android 上的角色。
- 不重写 hls.js 注入脚本的其它部分(广告过滤、网速上报、缓存区间上报保持现状)。
- 不引入新的播放器依赖。

## 回滚策略

改动集中在 `lib/widgets/player_adapter.dart` 单文件。一旦发现回归,直接 revert 该文件的改动即可,无破坏性数据迁移或外部依赖。

## 备注

- 详细技术方案(哪些参数改、改动分支放 Dart 侧还是 JS 侧、是否保留 `startLoad` 调用)留到 design 阶段。
- 由于本任务改动范围集中在单文件、改动行数有限,判定为轻量任务,PRD-only 即可,不强制 `design.md` / `implement.md`。如后续验证发现复杂度上升,再补 design。
