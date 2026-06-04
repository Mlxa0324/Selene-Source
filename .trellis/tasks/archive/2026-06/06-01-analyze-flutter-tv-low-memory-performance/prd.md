# 分析 Flutter TV 端在 2GB 运存设备上的流畅度优化

## Goal

让 Flutter TV 应用在 2GB RAM 的低端 Android TV 设备上流畅运行,重点解决详情页加载期焦点卡死和闪退问题。

## 问题现象

详情页 (`tv_video_detail_screen.dart`) 在数据加载等待期:
- 焦点无法移动(2GB 设备) vs 可正常移动(4GB 设备)
- 有几率闪退
- 页面加载期相对卡顿

## 根因分析

### 设备背景
- 2GB TV 设备: 系统占用 ~800MB-1GB, Flutter 引擎 ~200-400MB, WebView ~100-200MB, 剩余给 app 的仅 300-500MB
- 2GB TV 通常搭载弱 CPU(ARM A53/A55), 图片解码比手机慢 2-3 倍

### 详情页加载期的内存热点

1. **并发操作过多**: `initState` 同时触发播放记录查询、代理预热、收藏状态、广告偏好 4 个异步操作;数据返回后 `_startDetailLoading` 又并行发起精确源请求 + SSE 多站搜索
2. **setState 风暴**: 多个异步操作几乎同时回调 setState,从 loading spinner 一次性重建为包含播放器、线路列表、选集列表、推荐列表的复杂 widget 树
3. **图片解码阻塞 UI 线程**: 推荐区 15 张 TvVideoCard 同时解码,每张原始 800×1200 约 3-8ms → 累计 75ms+ 连续占用 UI 线程 → 焦点事件无法处理
4. **imageCache 过大**: Flutter 默认 `maximumSizeBytes` = 100MB, 2GB 设备可用内存少,频繁 GC → UI 线程抖动
5. **视频播放器过早初始化**: WebView + hls.js 在首屏就初始化,增加内存竞争
6. **TvVideoCard 动画开销**: 每张卡片包含骨架雨刷 AnimationController + 焦点雨刷 AnimationController,推荐区 15 张 + 选集区 + 线路区各有多张卡片同时维护动画

## Confirmed Facts

- TV 端使用 **WebView**(hls.js) 播放,不使用 media_kit,无需优化 native 解码器
- 图片已有磁盘缓存(`cached_network_image` + `flutter_cache_manager`),不需改磁盘策略
- TV 检测: `AppDeviceService` + native `isAndroidTv` + `DeviceModeConfig.forceTvMode`

## Requirements

### R1: 详情页加载期焦点可移动
- 进入详情页后,无论加载进度如何,遥控器方向键焦点应始终可正常移动
- 优先级: 必须

### R2: 降低详情页内存峰值,避免闪退
- 加载期内存峰值降低 30-40%
- 优先级: 必须

### R3: 图片解码按 TV 实际渲染尺寸限制
- TV 卡片封面解码高度限制为 237px(卡片封面固定高度)
- imageCache 上限从 100MB 降到 30-50MB(TV 专属)
- 优先级: 高

### R4: 推荐区延迟加载
- 相关推荐数据在首播请求下发后再启动,不抢占首屏资源
- 优先级: 高

### R5: 不影响其他端
- 所有优化仅在 Android TV 端生效
- Windows/macOS/手机端行为不变
- 优先级: 必须

## Acceptance Criteria

- [ ] 2GB Android TV: 详情页加载期焦点方向键可正常移动,无 200ms+ 延迟
- [ ] 2GB Android TV: 详情页从进入到可操作时间缩短 30%+
- [ ] 2GB Android TV: 连续进出详情页 20 次不闪退
- [ ] `cacheHeight` 优化后,TV 封面解码内存占用量降低 26 倍
- [ ] 其他端(Win/Mac/手机)图片加载行为不变
- [ ] 现有测试通过

## Out of Scope

- 首页其他分区优化(本次聚焦详情页)
- 全屏播放器优化
- 搜索页优化
- 磁盘缓存策略变更
- Kotlin/Android 原生端优化

## Notes

- 这是复杂任务,需要 `design.md` + `implement.md`
- 核心风险点: `cacheHeight` 可能改变部分卡片封面显示精度,需视觉验证
- `imageCache.maximumSizeBytes` 降低后需确认快速滚动时不出现频繁空白重载
