# TV 竖向列表快速滚动时优先加载可见区域图片

## Goal

竖向列表快速跨页滚动时,只加载当前可见区域内的封面图片,已滚过的中间页卡片不抢占网络带宽,等它们真正进入视口后再加载。

## 问题分析

当前 `_TvCoverImage` 的延迟加载机制:
- 滚动中: `Scrollable.recommendDeferredLoadingForContext` → 不加载图片,展示骨架
- 滚动停: 所有已构建的卡片(包括不可见的)同时解禁 → 并发发起图片请求

结果: 快速从第 1 页滚到第 4 页时,第 2、3 页的卡片虽然不在视口内,但滚动停止后仍会同时申请图片,抢占第 4 页的网络资源。

## Requirements

- 滚动停止后,仅当前视口内可见的卡片发起图片请求
- 不可见卡片继续保持骨架态,等进入视口后再自动加载
- 不能影响滚动中已有的延迟加载行为
- 复用现有 `_scheduleDeferredLoadingRetry` 重试机制,在重试时额外检查可见性

## Acceptance Criteria

- [ ] 快速跨页滚动后,不可见卡片保持骨架态
- [ ] 不可见卡片滑入视口后自动开始加载图片
- [ ] 现有卡片相关测试通过
- [ ] 不影响横向列表(首页继续观看、详情页线路/选集/推荐)的行为

## Notes

- 改动文件: `lib/tv_app/widgets/tv_video_card.dart` 的 `_TvCoverImageState`
- 核心逻辑: `_resolveCanStartImageRequest` 中增加视口可见性判断
- 视口检查可用 `RenderObject.isAttached` + 计算 `paintBounds` 与当前 viewport 的交集
- 可能需要 `design.md`,因为涉及延迟加载机制的扩展
