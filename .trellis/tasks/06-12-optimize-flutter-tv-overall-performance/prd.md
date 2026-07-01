# 优化Flutter TV端整体卡顿

## Goal

系统性分析并优化 Flutter TV 端的整体流畅度，重点覆盖详情页和全屏播放两大核心场景，同时兼顾首页、搜索等其他页面的性能表现。

## 已确认事实（来自代码库分析）

### 代码规模
- TV 端 Flutter 代码约 29,000 行，分布在 `lib/tv_app/` 下 34 个文件中
- 最大的两个文件：详情页 `tv_video_detail_screen.dart` (5,572行)、全屏播放器 `tv_fullscreen_player_screen.dart` (4,967行)
- 组件层 14 个文件约 6,490 行，服务层 9 个文件约 2,112 行

### 已有优化措施
1. 播放器图层缓存：菜单交互期间防止平台视图重建
2. 渐进式渲染：`TvVideoGrid` 首屏只渲染 80 张卡片，按需扩展
3. 延迟图片加载：滚动期间跳过网络图片请求，带可视窗口检测
4. 源列表缓存：避免 setState 重建期间重复排序
5. 卡片尺寸缓存：缓存 TextPainter.layout 结果
6. 滚动请求去重：90ms 窗口内重复请求只执行一次
7. setState 保护：`_scheduleChromeRefresh` 检查 SchedulerPhase
8. 播放器内核延迟解析：不阻塞首播
9. 推荐延迟加载：播放开始后延迟 2 秒
10. 封面骨架屏：有限次数的动画循环
11. RepaintBoundary：隔离首页分区的重绘
12. 退出保护标志：防止路由销毁后无用操作

### 已识别的性能瓶颈
- A. 高频 setState 调用（时钟定时器、滚动监听器、焦点变化）
- B. 大型 Widget 树一次性构建（详情页 build 渲染播放器 + 4 个列表 + 信息面板）
- C. 大量 addPostFrameCallback 调用（详情页约 50+，全屏约 30+）
- D. 动画复杂度（每卡片一个 AnimationController、边缘抖动、Tab 切换）
- E. FocusNode 生命周期管理（每页 50+ 个频繁创建/销毁）
- F. 图片内存管理（30MB 缓存上限）

## Requirements

- TBD (待明确)

## Acceptance Criteria

- [ ] TBD
