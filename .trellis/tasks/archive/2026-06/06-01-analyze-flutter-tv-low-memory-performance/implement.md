# Implement: Flutter TV 端低内存优化

## Checklist

### Step 1: TvVideoCard 封面解码尺寸限制
- [ ] 修改 `lib/tv_app/widgets/tv_video_card.dart`
  - `_TvCoverImageState.build()` 中的 `CachedNetworkImage` 添加 `memCacheHeight: 237`(取 `TvVideoCard.coverHeight.toInt()`)
  - 同方法中的 `Image.network` 添加 `cacheHeight: 237`
- **验证**: `flutter test test/tv_app/tv_video_card_test.dart` 通过

### Step 2: imageCache 内存上限
- [ ] 修改 `lib/tv_app/tv_app_shell.dart`
  - 在 `_TvAppShellState.initState()` 中调用 `PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;`
  - 添加 `import 'package:flutter/painting.dart';`
- **验证**: `flutter test test/tv_app/` 全部通过

### Step 3: 详情页推荐延迟到播放开始后加载
- [ ] 修改 `lib/tv_app/screens/tv_video_detail_screen.dart`
  - 新增可配置常量 `_recommendsDelayAfterPlayback`(默认 2 秒,之后可按需调整)
  - `defaultLoadDetail`: 移除 `final recommends = await _loadRecommends(...)`,改为 `const <VideoInfo>[]`
  - `_markMoreSourcesLoaded`: 去掉 `_loadRecommendsIfNeeded(forceWhenEmpty: ...)` 调用
  - `_updateControllerDataSource`: 去掉其中的 `_loadRecommendsIfNeeded()` 调用(不再在首播请求下发时触发)
  - `_markPreviewPlaybackStarted`: 新增延迟触发 `_loadRecommendsIfNeeded()`(播放开始 + 可配延迟后)
- **验证**: `flutter test test/tv_app/tv_video_detail_screen_test.dart` 通过

### Step 4: 全量测试
- [ ] `cd <project_root> && flutter test test/tv_app/` 全部通过
- [ ] 确认 3 个修改文件无 analyzer 警告

## Risky Files

| 文件 | 风险 | 缓解 |
|---|---|---|
| `tv_video_card.dart` | `cacheHeight` 可能影响封面清晰度 | 可随时调高或回退 |
| `tv_app_shell.dart` | imageCache 上限过低导致频繁重新解码 | 可调整到 50MB |
| `tv_video_detail_screen.dart` | 推荐区延迟可能导致旧测试断言失败 | 测试中推荐区可能始终为空,需更新断言 |

## Validation Commands

```bash
cd /Volumes/My2TDrive/StudioProjects/Selene-Source
flutter analyze lib/tv_app/widgets/tv_video_card.dart
flutter analyze lib/tv_app/tv_app_shell.dart
flutter analyze lib/tv_app/screens/tv_video_detail_screen.dart
flutter test test/tv_app/tv_video_card_test.dart
flutter test test/tv_app/tv_video_detail_screen_test.dart
flutter test test/tv_app/
```
