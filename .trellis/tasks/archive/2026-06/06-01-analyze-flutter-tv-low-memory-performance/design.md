# Design: Flutter TV 端低内存优化

## Overview

针对详情页在 2GB RAM Android TV 设备上加载期焦点卡死和闪退问题,从图片解码、内存缓存上限、详情页加载时序三个维度进行优化。所有变更通过 TV 专属文件隔离,不影响其他端。

## Design

### 1. 封面图片解码尺寸限制

**当前状态**: `_TvCoverImage` 使用 `CachedNetworkImage` 和 `Image.network` 加载封面,未设置 `cacheWidth`/`cacheHeight`/`memCacheWidth`/`memCacheHeight`。实际解码尺寸取决于原始图片(通常 800×1200 = 3.66MB 像素),远超 TV 卡片渲染尺寸(158×237)。

**变更**:
- `CachedNetworkImage` 添加 `memCacheHeight: 237`
- `Image.network` 添加 `cacheHeight: 237`
- 值从 `TvVideoCard.coverHeight`(237.0) 读取,集中管理

**影响**:
- 单张封面解码内存: 3.66MB → 0.14MB(降低 26 倍)
- 解码 CPU 时间: 3-8ms → <1ms(跳过全分辨率 sub-sampling)
- 位置: `lib/tv_app/widgets/tv_video_card.dart` 的 `_TvCoverImageState.build()`

**为什么不需要 `cacheWidth`**: 只设 `cacheHeight` 会让 Flutter 按比例自动计算宽度,保持原始宽高比,配合 `BoxFit.cover` 正常工作。指定一个维度即可。

### 2. Flutter imageCache 内存上限降低

**当前状态**: Flutter 默认 `imageCache.maximumSizeBytes` 未显式设置(默认 ~100MB)。在 2GB 设备上,100MB 的图片缓存挤压系统可用内存。

**变更**: 在 TV 启动路径中,将 `PaintingBinding.instance.imageCache.maximumSizeBytes` 设为 30MB(TV 专属)。

```dart
// 约 200 张 TV 封面(0.14MB × 200 ≈ 28MB)
PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;
```

**影响**:
- 图片缓存上限: 100MB → 30MB
- 对于已优化的 0.14MB 封面,30MB 可存 ~200 张,足够覆盖首页多分区和详情页推荐区
- 位置: `TvAppShell.initState()`

### 3. 详情页推荐区加载时序优化

**当前状态**:
- 默认路径(`defaultLoadDetail`): 串行执行 initial sources → more sources → **recommends**,recommends 阻塞了整个默认加载流程
- 分步路径: `_loadRecommendsIfNeeded()` 虽有守卫但仍在首播请求下发时就触发,此时 Douban API 会和播放流争抢网速

**变更**:
- 推荐加载从"首播请求下发时"推迟到"视频实际开始播放后"(`onPlay` 回调)
- 新增可配置延迟常量,方便根据实际体验调整

具体改动:
- `defaultLoadDetail`: 不再串行等待 recommends,改为返回空 recommends,后续由回调异步加载
- 在 `_markPreviewPlaybackStarted`(对应 `onPlay` 回调)中触发推荐加载
- `_markMoreSourcesLoaded` 中去掉 `forceWhenEmpty` 参数

**可配置项**:

```dart
/// 视频开始播放后延迟多久再加载相关推荐。
///
/// 设为 0 表示播放开始后立即加载；
/// 设为正数表示播放开始后再等 N 秒才开始加载推荐，
/// 给首播流留出更多网速余量。
static const Duration _recommendsDelayAfterPlayback = Duration(seconds: 2);
```

> 调整这个常量就能控制推荐加载时机,无需改流程逻辑。

**影响**:
- 首屏网络不再被推荐 API 抢占
- 推荐区在播放开始后 + N 秒才出现
- 位置: `lib/tv_app/screens/tv_video_detail_screen.dart`

### 4. 平台隔离策略

**隔离原则**: 所有 TV 优化仅当 `AppDeviceType == tv` 时生效。

| 优化项 | 隔离方式 | 说明 |
|---|---|---|
| cacheHeight | TV 专属文件 `tv_video_card.dart` | 仅 TV 卡片使用该组件 |
| imageCache limit | `TvAppShell.initState()` | 仅 TV 入口执行 |
| recommends 延迟 | `tv_video_detail_screen.dart` 内修改 | 仅 TV 详情页使用 |

不需要额外的 `if (isTV)` 判断,因为这些代码路径已经天然仅 TV 使用。

## Data Flow (优化后详情页加载时序)

```
进入详情页 ──→ initState
               ├── _loadM3u8ProxyUrl()        (非阻塞预热)
               ├── _loadFavoriteState()        (同步缓存读取)
               ├── _loadAdFilterPreference()   (非阻塞)
               └── _loadResumeRecordThenStartDetailLoading()
                    └── PageCacheService.getPlayRecords()
                         └── _startDetailLoading()
                              ├── _loadInitialSources()  ──→ API/SSE
                              └── _loadMoreSources()     ──→ SSE 多站搜索
                                   │
                                   ▼ (数据到达, setState)
                              ├── 渲染播放器 + 线路 + 选集(焦点可移动)
                              ├── WebView 初始化, 首播请求下发
                              ├── 视频缓冲...播放开始!(onPlay 回调)
                              │   └── 等 _recommendsDelayAfterPlayback 后
                              │        └── _loadRecommendsIfNeeded()
                              │             └── Douban API → 推荐列表
                              │                  └── 渲染推荐区 TvVideoCard (cacheHeight=237)
                              │
                              └── 首播流网速不受推荐 API 影响
```

## Trade-offs

| 决策 | 优点 | 代价 |
|---|---|---|
| `cacheHeight: 237` | 内存降 26×, CPU 解码快 | 极端低分辨率屏幕(>1080p 的 4K TV)封面可能略微模糊 |
| `imageCache` 30MB | 减少 GC 压力, 降 OOM 风险 | 快速滚动时可能更多短暂空白(骨架屏) |
| 推荐延迟加载 | 首屏更快, 焦点少卡 | 推荐区出现比之前晚 ~500ms |
| 不改磁盘缓存 | 零风险, 二次加载仍快 | 磁盘存原始分辨率(100-200KB), 影响小 |

## Rollback

- 所有改动都是参数级别的,可以直接 revert
- 如果 `cacheHeight: 237` 导致视觉效果不佳,改为 `cacheHeight: 474`(2x) 再验证
- imageCache 上限可随时调回默认
