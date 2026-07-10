# 修复设置页方向键焦点导航

## Goal

修复 Kotlin TV 设置页中遥控器方向键无法在表单控件间移动的问题，使用户能够连续浏览和操作全部设置项。

## Confirmed Facts

- `TvSettingsRoute` 仅将首焦点绑定到“服务器地址”，其余表单控件未建立显式的上下焦点关系。
- `TvFormTextField` 在浏览态会消费上、下方向键，并仅通过可选的 `onArrowUp`、`onArrowDown` 回调转交焦点；设置页未提供这两个回调，导致首个文本行直接阻断纵向导航。
- 设置页的控件为纵向表单，部分行内包含横向 Chip、开关或滑杆，需要保持行内左右操作，同时明确处理跨行上下移动。

## Requirements

- 为设置页全部可交互控件创建稳定的焦点目标，并按照页面视觉顺序连接上下方向。
- 文本输入行在浏览态按上、下键时转移到相邻表单项；进入编辑态后保持既有输入行为。
- Chip 选项行保持左右切换选项，按上、下键进入相邻表单项；从相邻行返回时定位到该行当前或最近一次获焦的 Chip。
- 开关、滑杆与操作按钮保持自身的左右或确认键操作，并可通过上、下键连续进入相邻表单项。
- 页面边界不跳出设置页面，不改变顶部导航与进入设置页的首焦点约定。
- 为焦点链补充回归测试，防止再次出现方向键被消费但没有转交目标的情况。

## Acceptance Criteria

- [x] 首焦点仍落在“服务器地址”，从顶部导航进入设置页的既有行为不变。
- [x] 从“服务器地址”开始按下键可依次到达账号、密码、保存配置及后续所有可交互设置项；按上键可按相反顺序返回。
- [x] 每个 Chip 行内左右键只在该行的 Chip 之间移动，上下键能够进入相邻表单项。
- [x] 开关和滑杆的左右操作不回归，确认键操作不回归。
- [x] 首项按上键、末项按下键不会将焦点跳出设置页。
- [x] 设置页焦点契约测试覆盖真实的焦点转交绑定，并通过目标模块测试。

## Out Of Scope

- 不调整设置项文案、布局、持久化逻辑或顶部导航的整体焦点策略。
- 不重构其他页面的焦点实现。

## Open Questions

- 无。按现有 TV 焦点规范实施即可。

## Notes

- 验证：`./re-android/gradlew -p re-android :core-design:testDebugUnitTest :feature-tv-settings:testDebugUnitTest` 通过。
- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
