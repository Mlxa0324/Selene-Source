# Implement: TV 列表可见区域图片优先级

## Checklist

### Step 1: 增加视口可见性判断方法
- [ ] 修改 `lib/tv_app/widgets/tv_video_card.dart`
  - `_TvCoverImageState` 新增 `_isInViewport(BuildContext)` 方法
  - 使用 `RenderAbstractViewport.of` + `Scrollable.maybeOf` 计算卡片与视口交集
  - 非滚动容器内或无法获取 viewport 时返回 true(安全回退)

### Step 2: 修改图片请求放行逻辑
- [ ] `_resolveCanStartImageRequest` 中,`_shouldDeferLoading` 返回 false 后增加 `_isInViewport` 检查
  - 不在视口 → `_scheduleDeferredLoadingRetry()` + return false
  - 在视口 → 设置 `_canStartImageRequest = true` + return true

### Step 3: 测试
- [ ] `flutter test test/tv_app/tv_video_card_test.dart` 全部通过
- [ ] `flutter test test/tv_app/tv_video_grid_focus_frame_test.dart` 全部通过

## Risky Files

| 文件 | 风险 | 缓解 |
|---|---|---|
| `tv_video_card.dart` | `RenderAbstractViewport.of` 在极端布局中返回 null | 回退到 true,正常加载 |
| `tv_video_card.dart` | `Scrollable.maybeOf` 查找开销 | 仅在重试循环中调用(120ms 间隔) |

## Validation Commands

```bash
flutter analyze lib/tv_app/widgets/tv_video_card.dart
flutter test test/tv_app/tv_video_card_test.dart
flutter test test/tv_app/tv_video_grid_focus_frame_test.dart
```
