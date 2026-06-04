# 固定 TV 全屏播放器一级菜单位置

## Goal

固定 TV 全屏播放器底部一级菜单按钮组的位置，避免切换不同二级菜单时最下面一排按钮上下跳动。

## Requirements

- 全屏播放器底部最下面一排一级菜单按钮必须固定在同一个垂直位置。
- 切换「播放列表、播放线路、画面比例、倍速、其它」时，只允许上方二级菜单内容变化，一级菜单行不得跟随内容高度上下移动。
- 保持现有遥控器焦点行为：一级菜单获焦切换二级菜单，上键进入二级菜单，下键留在一级菜单行。
- 当上方二级菜单内容较短时，底部弹框顶部必须跟随实际内容高度收紧，不能保留大块空白。
- 不改底部按钮视觉样式，不调整按钮颜色、边框、焦点态和字号。

## Acceptance Criteria

- [x] 切换到「其它」和「画面比例」等不同高度二级菜单时，「播放列表」等一级菜单按钮的 `top` 坐标保持一致。
- [x] 切换到「播放线路」和「画面比例」时，二级菜单与弹框顶部只保留正常顶部内边距。
- [x] 全屏菜单仍能正常通过下键打开，通过一级菜单焦点切换二级菜单。
- [x] 现有全屏播放器菜单尺寸和焦点测试通过。
- [x] 针对修改文件完成 `flutter analyze`、相关 `flutter test` 和 `git diff --check`。

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
