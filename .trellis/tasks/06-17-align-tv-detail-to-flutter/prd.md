# PRD: 详情页样式与交互对齐 Flutter TV

## Scope

继续缩小 Kotlin TV 详情页与 Flutter TV 的差距。

## 子任务 (按实现顺序)

### 1. Chip 获焦缩放动画
`TvDetailOptionChip` 加 1.08x scale 动画，匹配 Flutter `_TvChoiceChip`。

### 2. 选集分组选择器改为下划线样式
Flutter `_TvTextChoice`：纯文字 + 获焦时下划线，不用 chip 背景。

### 3. 底部操作按钮
推荐区之后加"观看历史"和"退出"按钮。

### 4. 预览区进度条 + 加载网速
播放器底部进度条 + 缓冲段。加载中显示网速。

### 5. SSE 流式搜索 + 降级
线路加载：SSE 流式搜索 (增量回调) → 精确匹配 → 本地搜索降级。

## 验收

- [ ] Chip 获焦 1.08x 缩放
- [ ] 分组选择器下划线样式
- [ ] 底部操作按钮可见
- [ ] 预览区进度条渲染
- [ ] SSE 搜索接通
