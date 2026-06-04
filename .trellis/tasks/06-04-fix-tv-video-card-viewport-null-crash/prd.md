# 修复 TV 视频卡片封面视口判定空指针

## Goal

定位并修复 TvCoverImage 在 FutureBuilder 构建期间调用 RenderViewportBase.getOffsetToReveal 触发 Null check operator used on a null value 的崩溃。根因确认后先向用户确认，再实施修复。

## Requirements

- 先定位 `TvCoverImage` 在构建期触发 `RenderViewportBase.getOffsetToReveal` 空断言的根因。
- 根因确认后先向用户说明并等待确认，再进入代码修复。
- 修复后保持 TV 卡片滚动期间延迟发起封面图片请求的既有行为。
- 无法稳定计算视口位置时，封面加载链路必须安全回退，不允许因次要图片请求优化导致页面构建崩溃。
- 补充 `test/tv_app/tv_video_card_test.dart` 回归测试覆盖崩溃场景。

## Acceptance Criteria

- [x] 进入详情页、继续观看或影视卡片列表时，不再出现 `Null check operator used on a null value`。
- [x] 卡片在可见视口内仍能正常发起真实封面图片请求。
- [x] 卡片在滚动或不可见时仍优先展示骨架，不产生图片请求风暴。
- [x] 新增或更新的 TV 卡片测试通过。
- [x] 针对修改文件完成 `flutter analyze` 和 `git diff --check` 验证。

## Root Cause Notes

- 崩溃堆栈指向 `_TvCoverImageState._isInViewport` 在 `FutureBuilder` 构建期间调用 `RenderViewportBase.getOffsetToReveal`。
- 当前代码注释声明“无法获取 viewport 时安全回退到允许加载”，但实现使用 `RenderAbstractViewport.of(renderObject)` 并直接调用 `getOffsetToReveal`。
- Flutter 内部 `getOffsetToReveal` 会沿目标 `RenderObject` 的父链回溯到 viewport，并对 `child.parent` 与 `childScrollOffset(child)` 使用非空断言；当 Sliver/Viewport 子节点在更新或布局未稳定时，目标节点可能暂时不是可安全 reveal 的路径，因而触发内部空断言。
- 同仓库 `TvFocusScroll` 已采用 `RenderAbstractViewport.maybeOf` 并在布局稳定后的 post-frame 中计算滚动位置，说明此类 viewport 计算需要先判空并避开构建期脆弱状态。

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
