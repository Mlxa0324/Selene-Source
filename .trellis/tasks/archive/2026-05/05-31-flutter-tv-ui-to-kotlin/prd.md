# 复刻 Flutter TV UI 到 Kotlin

## Goal

将现有 Flutter TV 端 UI 与交互完整复刻到 `re-android/` Kotlin 原生 Android TV 工程。父任务作为总控与最终集成验收任务，具体实现拆分为 4 个可独立验收的子任务推进。

## User Value

- 让 Android TV 端摆脱 Flutter TV UI 依赖，形成可独立迭代的 Kotlin/Compose TV 实现。
- 保留 Flutter TV 已打磨过的首页、详情页、搜索、历史、收藏、设置、直播、播放器和遥控器体验。
- 后续性能、播放器内核、遥控器适配和原生能力可以直接在 Kotlin 工程中演进。

## Confirmed Facts

- Flutter TV 源实现位于 `lib/tv_app/`，核心入口是 `lib/tv_app/tv_app_shell.dart`。
- Flutter TV 已有页面包括：首页、搜索、历史、收藏、设置、直播、详情、全屏播放器、弹幕匹配。
- Flutter TV 关键组件包括 `TvDesignCanvas`、`TvTopNav`、`TvFocusable`、`TvVideoCard`、`TvVideoGrid`、`TvHomeSection`、`TvBackHandler`、`TvEdgeShake`、TV 确认弹窗与弹幕 overlay。
- Flutter TV 规格已记录在 `.trellis/spec/frontend/tv-mode.md`，包含设计视口、顶部导航、焦点、详情页分段加载、播放记录、设置桥接等契约。
- Kotlin 工程位于 `re-android/`，当前已有多模块骨架：`app-tv`、`core-design`、`core-data`、`core-network`、`core-player-*`、`feature-tv-*`。
- Kotlin README 明确当前 UI 和数据链路已对齐 Flutter TV 端首期行为，迭代工作按模块验收推进。
- Kotlin 当前 `TvNavGraph` 已接入真实详情、播放器和功能页路由，TV 页面已清理用户可见占位文案。
- 工作区已有大量 `re-android/` 未提交改动，本任务实施时必须先识别并保护这些既有改动。

## Requirements

- 复刻范围必须以 Flutter TV 端为源：优先读取 `lib/tv_app/` 和对应 `test/tv_app/`，不要凭空设计 Kotlin 端新 UI。
- Kotlin 目标实现使用现有 `re-android/` 多模块结构，不新建平行 Android 工程。
- 本任务拆成子任务推进；父任务不直接实现业务代码，负责维护总范围、跨子任务验收和最终集成检查。
- 子任务顺序：
  1. `05-31-kotlin-tv-design-shell`：设计系统、根壳、导航和焦点基础。
  2. `05-31-kotlin-tv-home-library`：首页、顶部导航使用、分类/视频库列表。
  3. `05-31-kotlin-tv-detail-player`：详情页、全屏播放器壳、播放源/选集/推荐。
  4. `05-31-kotlin-tv-pages-acceptance`：搜索、历史、收藏、设置、直播、弹幕入口和全量验收。
- 页面级复刻至少覆盖：
  - TV App Shell 与根导航。
  - 首页与顶部导航。
  - 分类/视频库列表。
  - 搜索页。
  - 详情页。
  - 全屏播放器壳与菜单。
  - 播放历史页。
  - 收藏夹页。
  - 设置页。
  - 直播页当前 Flutter 对应状态。
  - 弹幕匹配/弹幕展示相关 TV UI，如 Kotlin 当前尚无对应入口，需要在设计中明确落点。
- 组件级复刻至少覆盖：
  - 设计视口与缩放策略。
  - TV 主题 token、页面壳、分区、海报卡片、横向 rail、纵向 grid。
  - 顶部导航的主分类、右侧快捷入口、当前时间、焦点回流。
  - 遥控器焦点封装、短按/长按/重复按键处理、自动滚动、边缘 shake。
  - 空状态、加载态、错误态、确认弹窗。
- 数据链路必须尽量复用现有 Kotlin `core-data/core-network` 仓库层；缺失能力按 Flutter 行为补齐仓库契约。
- 测试必须覆盖核心 ViewModel、路由参数、焦点/按键策略、页面状态转换和关键 Compose UI 结构。
- 视觉复刻应以可验证的布局/token/状态对齐为准；若无法做截图级 1:1 自动比对，至少用代码清单和人工验收 checklist 固化差异。

## Acceptance Criteria

- [x] 四个子任务均完成并归档。
- [x] `re-android/` 中不再存在面向最终用户的 TV 页面骨架占位文案，例如“后续再接”“占位”“骨架已接入”等。
- [x] Kotlin TV 首页具备 Flutter TV 同等顶部导航、快捷入口、时间展示、分区 rail、继续观看、热门、历史、收藏和空/加载/错误状态。
- [x] Kotlin TV 详情页具备 Flutter TV 同等左侧预览/播放器入口、标题信息、线路切换、选集、推荐、首源快速起播、后台补源和错误/加载状态。
- [x] Kotlin TV 搜索、视频库、历史、收藏、设置、直播页面与 Flutter TV 对应页面的信息架构和焦点行为一致。
- [x] Kotlin TV 全屏播放器壳接入真实 player route，不再使用导航占位；核心菜单和播放快照恢复行为对齐 Flutter TV/现有 Kotlin player 设计。
- [x] `core-design` 提供 Flutter TV 关键通用组件的 Compose 等价物，feature 页面不得重复手写同类布局。
- [x] 遥控器确认键短按、长按、KeyRepeat、防重复 push、上下左右焦点记忆和自动滚动行为有测试覆盖。
- [x] 关键 Kotlin 单元测试通过，至少包括受影响模块的 `testDebugUnitTest`。
- [x] Android lint/编译验证在可用环境中通过；如因环境限制无法运行，记录具体失败原因。
- [x] 最终提交只包含本任务相关文件，不混入已有无关 dirty 改动。

## Out of Scope

- 不重写 Flutter TV 端。
- 不引入新的非 Kotlin Android 工程。
- 不把 DLNA、本地离线下载等 README 已标注未接入能力强行纳入首轮复刻，除非 Flutter TV UI 中已有必须展示的入口状态。
- 不承诺自动像素级截图比对，除非后续明确建立截图基准和运行环境。

## Open Questions

- None. 用户已确认拆成子任务推进。
