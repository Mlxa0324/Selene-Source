---
name: flutter-performance-optimization
description: Use when Flutter pages, player flows, image-heavy lists, or TV/remote UIs feel janky, slow to first frame, blocked by secondary requests, or are doing too much work during rebuilds, scroll, focus, or route transitions.
---

# Flutter Performance Optimization

## Overview

在 Selene 里做 Flutter 性能优化时，先用这个 skill。

核心原则只有一句话：**首帧、首焦点、首播链路必须只做“必须现在完成”的事，所有次要任务都要异步拆开，互不阻塞。**

这个 skill 既适用于普通 Flutter 页面，也适用于 `lib/tv_app/` 下的 TV 焦点页面、播放器链路、图片重列表和骨架屏场景。

## When to Use

- 页面“能跑，但卡”
- 详情页、播放器、搜索页、首页感觉发涩
- 首帧慢、首播慢、滚动掉帧、焦点切换发抖
- 推荐数据、配置读取、图片加载、骨架动画互相拖累
- `build` 很频繁，getter 里还在排序、过滤、重建集合
- TV 页面方向键一动就伴随额外滚动、重绘或重复请求

不要用于：

- 纯视觉文案调整，且不涉及状态链路、异步链路或性能风险
- 单纯字段透传、无 UI 性能敏感路径的改动

## Execution Flow

1. 先读 `.trellis/spec/frontend/index.md`；如果涉及 TV，再读 `.trellis/spec/frontend/tv-mode.md` 和 `.trellis/spec/guides/index.md`。
2. 先归类症状：首帧、首播、滚动、焦点、重建、图片、骨架、路由、返回链路。
3. 先写最小失败用例，再修代码。优先补精准 widget test 或 service test。
4. 明确“关键链路”和“次要链路”：
   - 关键链路：不完成就无法首屏可见、无法首个可播放状态、无法稳定操作。
   - 次要链路：推荐、补源、配置预热、装饰动画、延后图片、后台统计。
5. 优先做三类修复：
   - 拆等待链，避免无关 `await`
   - 缓存派生数据，避免重复排序/过滤
   - 收紧滚动和焦点副作用，避免无意义 `ensureVisible/animateTo`
6. 修完后必须验证：
   - 目标 `flutter test`
   - 针对性 `flutter analyze`
   - `git diff --check`

## Quick Symptom Map

| 症状 | 优先查看 |
| --- | --- |
| 详情页进去久、播放器晚起播 | `flutter-performance-playbook.md` 的“首帧与首播链路” |
| 首页、搜索、纵向 Grid 掉帧 | “滚动、焦点与列表” |
| build 频繁，getter 里仍有排序/过滤 | “重建与派生数据” |
| 骨架屏、雨刷、图片加载抢资源 | “占位动画与图片加载” |
| 改 TV 后波及手机、返回链路异常 | “跨端隔离与回归” |

## Required Output

每次使用这个 skill，都要明确给出：

- 性能问题属于哪一类
- 关键链路与次要链路的拆分
- 具体修复策略
- 实际跑过的验证命令
- 剩余风险或暂缓项

## Reference

实现前必须通读 [flutter-performance-playbook.md](flutter-performance-playbook.md)。
