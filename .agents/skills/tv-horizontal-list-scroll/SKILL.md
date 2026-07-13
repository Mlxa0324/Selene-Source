---
name: tv-horizontal-list-scroll
description: Use when changing TV horizontal lists, chip rows, episode/source rows, home section rows, fullscreen player secondary menus, or any TV remote focus scrolling that involves left/right padding, leading pin, focus scale clipping, edge shake, or “card flush to screen edge” bugs.
---

# TV 横向列表滚动规范

## Overview

TV 端横向列表不是“左右各加一段 padding”这么简单。

产品观感目标只有一句话：

**默认看左侧永远有呼吸边距；右侧默认像没有边距、内容可以顶到屏幕右缘；只有滚到最右端时，最后一项才需要完整露出并带出右边框感。**

同时必须满足遥控器焦点安全：

**无论滚到最左还是最右，获焦卡片的描边/放大后轮廓都不能和模拟器/屏幕边框重合或被裁切。**

这个 skill 用于改 `lib/tv_app/` 里所有横向可滚动列表，尤其是：

- 首页分区 `TvHomeSection`
- 详情页线路/选集/推荐
- 全屏播放器底部二级菜单
- 搜索推荐横向列表
- 任意 chip / 卡片横滑行

## When to Use

- 用户说“左边缺 padding / 右边有空白 / 最左最右被裁切”
- 焦点放大后首项或末项描边消失
- 明明写了 padding，滚到最左/最右仍贴屏边
- 贴左 pin 后首项反而更贴边
- 改 `ListView`/`SingleChildScrollView` 横向 padding、`ensureVisible`、`animateTo`、`jumpTo`
- 修 `focusedScale`、`TvEdgeShake`、`clipBehavior` 相关裁切

不要用于：

- 纯纵向 Grid 且不涉及横向滚动（可只参考 focus safe 概念）
- 手机端列表

## Visual Contract（必须先对齐）

### 1. 静止默认态（offset ≈ 0）

| 侧边 | 观感 | 含义 |
| --- | --- | --- |
| 左侧 | **有 margin/padding** | 首项与页面标题/内容左基线对齐，看起来像页面边距 |
| 右侧 | **看起来没有 padding/margin** | 右侧不留大块空白槽；后续卡片可逼近甚至视觉上“从右缘进出” |

### 2. 中段滚动

- 卡片可以从右侧进入/离开视口
- 不要做成“左右始终各留同样大的固定空白”
- 焦点移动时优先“列表滚、焦点相对稳定”，而不是焦点先撞边再硬跳

### 3. 滚到最右端（offset ≈ max）

- 最后一项必须完整可见
- 右侧这时才出现“边框感 / 收住感”
- 末项获焦放大后，右侧仍要有安全空间

### 4. 绝对禁止

- 卡片未获焦时就贴死屏幕左右边
- 获焦后描边/放大轮廓与屏幕边框重合
- padding 写了，但 pin/scroll 逻辑又把内容滚到 padding 外侧
- 左/右无法滚到真正的 min/max（卡死在中间，或永远差一截）

## Geometry Model

把横向列表想成三层，不要混：

```text
[Screen]
  [Viewport 视口]          // 尽量贴到屏幕左右，允许内容从边缘进出
    [Content padding]      // 决定首尾项“停稳”时的安全位置
      [Item + focusedScale]// 放大溢出必须算进安全区
```

### 关键尺寸

| 符号 | 典型来源 | 作用 |
| --- | --- | --- |
| `pagePad` | `TvLayout.pageHorizontalPadding`（当前 46） | 页面左基线 / 大列表左安全区 |
| `focusSafe` | 如 `TvVideoGrid.focusSafePadding=12` 或菜单内 12 | 仅焦点描边/放大溢出缓冲 |
| `focusedScale` | `TvVideoCard.focusedScale = 1.08` | 左右各约 `width * 0.04` 溢出 |
| `clipBehavior` | 横向列表必须 `Clip.none` | 否则放大和描边直接被父级裁掉 |

### 推荐 padding 形态

#### A. 页面级横向列表（首页/详情/推荐）

目标：左有页边距，右默认“无边”，末端收住。

```dart
// 视口可贴屏；内容自己管安全区
padding: EdgeInsets.only(
  left: pagePad,          // 默认左呼吸 / 与标题对齐
  right: pagePad * 2~3,   // 末端才够末项+放大完整露出
);
```

常见配套：

- 标题保留 `pagePad`
- 列表视口可用 `OverflowBox` 左右扩出，抵消父级 page padding，让滚动内容能贴到屏边进出
- 但 **停稳项** 仍必须回到 left safe / right safe，不能停在 0 边线上

#### B. 已在带边距容器内的二级菜单（全屏播放器底部菜单）

外层容器已有左右 padding（如 32）时：

```dart
padding: EdgeInsets.only(
  left: focusSafe,        // 12
  right: focusSafe * 2,   // 24，末端更宽
);
```

不要再叠加一整段 `pagePad`，否则菜单里会太空；但 **绝不能为 0**。

### 不对称是特性，不是 bug

TV 产品要的是：

- 左：永远像有边
- 右：默认像没边，末端才有边

因此：

- `left == right` 通常不符合目标
- `right > left` 是正常解
- “右侧看起来没 padding”指的是 **默认视效**，不是 `right: 0` 且可裁切

## Scroll / Pin Rules

### Rule 1：padding 是停靠点，不是装饰

`ListView/SingleChildScrollView.padding` 决定：

- 首项在 `offset=0` 时的左停靠位置
- 末项在 `offset=max` 时的右停靠位置

任何 `jumpTo/animateTo/ensureVisible/pinNearLeading` 都必须尊重它。

### Rule 2：offset=0 时首项已在左安全区

若列表自身带 `padding.left = L`：

```text
targetOffset(index) ≈ index * (itemExtent + spacing)
// 不要再额外 - L，也不要 + leadingBias 把首项往左挤
```

错误示范：

```dart
// 错：把首项继续往左推，最终视觉贴屏边
offset = index * extent + leadingBias;

// 错：重复减 padding，导致滚不到真正最左/位置抖动
offset = index * extent - listPaddingLeft;
```

### Rule 3：贴左必须以“安全左缘 + 放大溢出”为对齐线

真实布局测量时：

```dart
scaleOverflow = itemWidth * (focusedScale - 1) / 2;
delta = targetRect.left
      - listRect.left
      - leftSafePadding
      - scaleOverflow;
targetOffset = (position.pixels + delta)
    .clamp(minScrollExtent, maxScrollExtent);
```

禁止：

```dart
// 错：对齐 list 物理左缘，获焦后左边被裁
delta = targetRect.left - listRect.left;
```

### Rule 4：右侧末端必须可滚到位

检查这三件事同时成立：

1. `maxScrollExtent` 足够大
2. `padding.right` 足够覆盖：末项放大溢出 + 视觉收口
3. 没有父级 `clip` 把溢出裁掉

若末项获焦后右侧描边被吃，优先：

1. 加大 `padding.right`（常见 `left * 2` 或 `* 3`）
2. 视口 `clipBehavior: Clip.none`
3. 父级不要 `Clip.hardEdge` 包死横滑行

### Rule 5：左右边界反馈不等于贴边

到边界时：

- 继续按方向键：`TvEdgeShake` 抖动
- 不要靠“把卡片顶到屏幕边缘”表达边界

### Rule 6：焦点滚动职责拆分

| 场景 | 推荐 |
| --- | --- |
| 普通浏览、让项进入可视区 | `TvFocusScroll.ensureVisible` / 通用 reveal |
| 需要“当前项贴左安全线” | 专用 pin-to-safe-leading |
| 纵向恢复焦点后保持横向 offset | 抑制一次横向 pin，避免跳动 |

不要所有焦点变化都 `ensureVisible + pinLeading` 连打两枪。

## Decision Tree

改 TV 横向列表前先问：

1. **这是页面级列表，还是已在带边距容器内的菜单行？**
   - 页面级：左用 `pagePad`，右用更大 end pad
   - 菜单内：左用小 `focusSafe`，右用 `focusSafe * 2`
2. **视口要不要贴屏？**
   - 需要内容从屏缘进出：viewport flush + content padding
   - 不需要：容器内直接 content padding
3. **有没有 `focusedScale` / 白色描边？**
   - 有：左右安全区必须计入 `width * (scale-1)/2`
4. **有没有自定义 pin/leading 逻辑？**
   - 有：按 Rule 2/3 重算，删掉 leadingBias
5. **最左/最右是否可完整露出？**
   - 写测试量 `itemRect` 相对 `listRect/screen` 的 gap

## Implementation Checklist

改完代码前自检：

- [ ] 默认态：首项左侧有稳定 gap（页边距或菜单安全区）
- [ ] 默认态：右侧没有大块空白槽感
- [ ] 首项获焦：左侧 gap >= safe，描边不被裁
- [ ] 任意项 pin 到最左获焦：仍保留 left safe + scale overflow
- [ ] 末项获焦：右侧 gap 足够，描边不被裁
- [ ] `clipBehavior: Clip.none`
- [ ] 边界键有 shake，不靠贴边表达边界
- [ ] 没有“有 padding 却滚到与屏幕边重合”
- [ ] 没有“设置了 padding 但滚不到最左/最右”

## Test Requirements

至少覆盖：

1. **首项安全左距**
   - 获焦后 `item.left - list.left >= minSafe`
   - 且 `<= maxExpected`（避免过大空白）
2. **末项安全右距**
   - 滚到最后并获焦后 `list.right - item.right >= minSafe`
3. **pin 不破坏安全区**
   - 从中间项左移/贴左后，gap 仍在安全区间
4. **焦点放大仍可见**
   - `focusedScale` 场景下描边矩形不越出屏幕（或越出量被 safe 吸收）

断言时不要只检查 `offset == 0/max`，要量真实 `Rect`。

## Common Failure Modes

| 现象 | 根因 | 修法 |
| --- | --- | --- |
| 首项左边被裁 | padding=0 或 pin 对齐物理左缘 | 加 left safe；pin 扣 safe+scale |
| 写了 padding 仍贴屏边 | pin/bias 把内容推出 padding | 删 leadingBias；offset 别再减错 |
| 右侧默认一大块空 | left/right 对称过大 | 右 pad 只服务末端，默认靠 flush viewport |
| 末项右边被裁 | right pad 不够或父级 clip | 增大 right；`Clip.none` |
| 滚不到最左/最右 | maxExtent 估算错、重复扣 padding、尾部 spacer 缺失 | 修正 extent 计算；必要时尾部补 viewport 宽 |
| 焦点一进就抖一下 | ensureVisible 与 pin 抢滚动 | 单一职责，抑制重复请求 |

## Canonical References in This Repo

实现时优先对照，不要各写一套魔法数：

- 页面边距：`lib/tv_app/tv_layout.dart` → `TvLayout.pageHorizontalPadding`
- 焦点放大：`lib/tv_app/widgets/tv_video_card.dart` → `TvVideoCard.focusedScale`
- 首页横滑：`lib/tv_app/widgets/tv_home_section.dart`
- 详情横滑 + safe leading pin：`lib/tv_app/screens/tv_video_detail_screen.dart`
- 全屏菜单横滑：`lib/tv_app/screens/tv_fullscreen_player_screen.dart`
- 焦点滚动工具：`lib/tv_app/widgets/tv_focus_scroll.dart`
- 边界抖动：`lib/tv_app/widgets/tv_edge_shake.dart`

## Required Output

使用本 skill 修改列表后，回复里要写清：

1. 属于页面级列表还是容器内菜单行
2. left/right padding 取值与原因
3. pin/scroll 是否按 safe leading + scale overflow 计算
4. 如何验证最左/最右不会贴屏裁切
5. 跑过的测试命令



## Multi-layer Vertical Keep Offset（Kotlin TV 全局）

多层横向列表（首页多轨、详情线路/选集/分组/推荐、播放器一级/二级菜单）上下切换时：

| 场景 | 行为 |
| --- | --- |
| 同轨左右相邻 | 允许横向 `animateScroll` / pin |
| 上下离开某层 | **不得**把该层横向 offset 复位到 0/首项 |
| 上下再进入 | 保持离开前的横向位置；仅同轨左右再移动才推进 |

### 实现契约（Kotlin）

共享策略：`TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll`

1. `previousActiveIndex = NoActiveIndex`（上下跨层进入时清会话）→ **不滚**
2. `abs(new - previous) == 1` → **滚**
3. 其它落点（程序聚焦、跨多项）→ **不滚**（显式跨组滚动可单独调用）
4. 多层 `LazyListState` 优先 `rememberSaveable(LazyListState.Saver)`，保证离开再回来 offset 仍在

### 反例

```kotlin
// 错：每次 onFocusChanged 都 pin/animate，上下回来会把横向列表拽回
if (focused) animateScrollToItem(index)
```

```kotlin
// 对：先问策略，再决定是否横向推进
val shouldScroll = TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
    previousActiveIndex = activeFocusedIndex,
    newlyFocusedIndex = index,
)
activeFocusedIndex = index
if (shouldScroll) scrollIntoView(...)
```

### Checklist 增补

- [ ] 上下切换：被移开列表横向位置不变
- [ ] 再进入：不会强制跳回第一项/最左
- [ ] 同轨左右：仍可跟手滚动
- [ ] 显式跨组/切源：可单独 scroll，不依赖 “每次获焦都滚”


## One-line Rule

**左常驻呼吸边，右默认贴边出，末端收住并护焦点；padding 管停靠，scroll 不许把安全区滚没。**
