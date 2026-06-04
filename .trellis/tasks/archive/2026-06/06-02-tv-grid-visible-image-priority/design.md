# Design: TV 列表可见区域图片优先级

## Overview

在现有 `_TvCoverImage` 延迟加载机制上增加视口可见性判断。滚动停止后,仅对当前视口内可见的卡片放行图片请求,不可见卡片继续保持骨架态,等真正进入视口再加载。

## Design

### 当前流程

```
_rebuild (每帧)
  └→ _resolveCanStartImageRequest
       ├─ _canStartImageRequest? → 直接放行
       ├─ _shouldDeferLoading? (Scrollable.recommendDeferredLoadingForContext)
       │    └─ true → _scheduleDeferredLoadingRetry(120ms) → 展示骨架,下次重建再判断
       └─ false → _canStartImageRequest = true → 放行
```

**问题**: `_shouldDeferLoading` 只表示"是否在滚动动画中",滚动停止后对所有卡片同时放行,不管是否可见。

### 新流程

```
_rebuild (每帧)
  └→ _resolveCanStartImageRequest
       ├─ _canStartImageRequest? → 直接放行
       ├─ _shouldDeferLoading? → _scheduleDeferredLoadingRetry → 骨架
       ├─ _isInViewport? → 放行
       └─ 不在视口 → _scheduleDeferredLoadingRetry → 骨架,下次重建再判断
```

**新增**: 滚动停止后多一步视口检查。不在视口的卡片保持重试循环,直到 `_isInViewport` 返回 true。

### 视口判断

```dart
bool _isInViewport(BuildContext context) {
  final renderObject = context.findRenderObject() as RenderBox?;
  if (renderObject == null || !renderObject.attached || !renderObject.hasSize) {
    return false;
  }

  final scrollable = Scrollable.maybeOf(context);
  if (scrollable == null) return true; // 非滚动容器内,正常加载

  final position = scrollable.position;
  final viewportHeight = position.viewportDimension;
  final scrollOffset = position.pixels;

  // 卡片在滚动坐标系中的位置(通过 RenderAbstractViewport 换算)
  final viewport = RenderAbstractViewport.of(renderObject);
  if (viewport == null) return true;

  final revealedOffset = viewport.getOffsetToReveal(renderObject, 0);
  final cardTop = revealedOffset.offset - scrollOffset;
  final cardBottom = cardTop + renderObject.size.height;

  return cardBottom > 0 && cardTop < viewportHeight;
}
```

**说明**: 使用 `RenderAbstractViewport.of` 获取卡片在可滚动坐标系中的位置,与当前 `scrollOffset` + `viewportHeight` 比较。返回 true 表示卡片有任意部分在视口内。

### 改动范围

| 文件 | 改动 |
|---|---|
| `lib/tv_app/widgets/tv_video_card.dart` | `_TvCoverImageState` 增加 `_isInViewport` 方法,修改 `_resolveCanStartImageRequest` |

**不需要改**: `TvVideoCard` 公开 API、`TvVideoGrid`、其他使用方。

### 边界情况

| 场景 | 处理 |
|---|---|
| 首页首屏渲染 | `_shouldDeferLoading` 为 false(无滚动动画),`_isInViewport` 检查 → 可见卡片立即加载 |
| 搜索/筛选后列表重建 | `didUpdateWidget` 重置 `_canStartImageRequest`,触发重新判断 |
| 列表 resize(窗口变化) | 下次 `_scheduleDeferredLoadingRetry` 触发时重新计算视口 |
| 非滚动容器 | `Scrollable.maybeOf` 返回 null → 跳过视口检查,正常加载 |

## Trade-offs

| 决策 | 优点 | 代价 |
|---|---|---|
| 基于 RenderAbstractViewport 计算 | 精确,适应不同布局 | 每 120ms 重试时走一次 render 树 |
| 仅改 `_TvCoverImage` | 改动最小 | 无法控制"真正在加载的图片数量上限" |
| 延续 120ms 重试间隔 | 现有时序不变 | 不可见卡片滑入后最多 120ms 延迟才加载 |
