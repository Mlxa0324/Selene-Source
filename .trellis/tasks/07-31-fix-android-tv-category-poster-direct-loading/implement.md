# Flutter 全端分类封面加载问题分析与最小修复执行计划

> 用户已授权修复源码确认的 Flutter 重复异步工作。本计划不修改图片 URL、请求头、直连/代理选择、分页接口、`re-android` 或 `kotlin-tv`。

## Step 1: Identify the Actual Flutter APK and Route

- [x] 记录 `git status --short`，并保留 PIP 任务已提交的独立改动。
- [x] 通过项目入口和代码路径确认 Flutter Android APK、Flutter TV 壳和普通 Flutter 页面实现。
- [x] 记录当前环境限制：无 Android 设备，无法确认 APK 运行时 HTTP/解码指标；直连配置和 URL 静态路径已核对。
- [x] 确认四个 Tab（电影、剧集、动漫、综艺）实际映射的页面、数据加载器、列表组件和图片组件。

## Step 2: Build the Reproduction Matrix

- [ ] 每个 Tab 至少记录四类样本：首屏未缓存、后续页未缓存、已有缓存、分页未触发/已触发。
- [ ] 分别记录列表数据是否已经追加、卡片是否已经组合、焦点是否接近末尾、图片请求是否开始。
- [ ] 对同一个标题记录原始封面字段、最终 URL、图片源 key、缓存 key 和请求头摘要。
- [ ] 记录请求开始到响应、解码和绘制的时间；没有现成日志时标记该项为“不可观测”，不自行补埋点。
- [ ] 直连模式可以作为默认复现条件；切换到代理源只能作为对照，不得将对照结果当成修复。

## Step 3: Static Flutter Cross-Implementation Audit

- [x] 审核 Flutter 普通分类页的分页、`DoubanMoviesGrid`、`VideoCard`、`getImageUrl` 和缓存/请求头链路。
- [x] 审核 Flutter TV 的 `TvVideoGrid` 懒构建、`_TvCoverImage` 的 URL/cache/deferred/viewport 组合，以及四个 Tab 的分页状态。
- [x] 对比两条 Flutter 链路对封面字段、空 URL、协议相对 URL、图片 host 和 Referer/UA 的处理差异。
- [x] 检查“后续页数据模型覆盖/列表追加丢失”和“请求已经发出但 UI 被回收”的独立可能，并记录为未由静态证据确认的风险。

## Step 4: Runtime Evidence and Root-Cause Report

- [ ] 使用现有 `adb logcat`、Flutter 日志、系统网络/调试工具和页面状态记录，定位每个异常样本停留的阶段。
- [x] 对每个根因给出：证据、反证、置信度、影响 Flutter 页面、复现条件和最小后续修复范围。
- [x] 将普通 Flutter 与 Flutter TV 的共同根因和端特有根因拆开；仅对已确认重复配置/缓存读取问题直接修复。
- [x] 将最终分析和修复结果写入任务文档/研究记录，并明确设备可用后的下一步验证范围。

## Step 5: Flutter-Only Fix and Verification

- [ ] 运行只读检查：

```bash
git diff --check
git diff --name-only
python3 ./.trellis/scripts/task.py current --source
```

- [x] 为共享图片源配置缓存、并发读取合并和 TV 默认缓存策略复用补 focused tests。
- [x] 运行相关 `flutter test`、`flutter analyze`、`git diff --check`，并确认差异没有 `re-android`/`kotlin-tv`/pub 缓存。
- [x] 记录无法由当前无设备环境验证的 HTTP、DNS、反盗链、解码和真实滚动体验风险。
