# Flutter TV 搜索联想词选中后直接搜索

## Goal

Flutter TV 搜索页左侧输入首字母后，右侧联想结果被选中时直接发起搜索，不再要求用户回到左侧手动点搜索。

## Requirements

- Flutter TV 搜索页左侧输入纯首字母后，右侧展示联想结果。
- 用户在右侧联想结果中确认任意词条时，直接使用该联想词发起搜索。
- 选中联想词后右侧应切换为搜索结果区，不再先回到搜索主页等待用户手动点“搜索”。
- 搜索请求使用联想词完整文本，不使用左侧首字母输入串。
- 搜索结果页仍保留进入前的首字母联想上下文，按返回键时可以回到原联想结果列表继续选择其它词。
- 保留“联想词回填后可编辑再手动搜索”的能力；该路径只在用户主动编辑已回填搜索词时使用。
- 保持搜索历史、热词、推荐区、结果区焦点流转和现有返回键行为不回退。
- 更新 `test/tv_app/tv_search_screen_test.dart` 中旧的“选中联想词不搜索”预期，新增或调整 widget test 覆盖自动搜索行为。

## Acceptance Criteria

- [x] 点击/确认右侧联想词后，`loadSearchResults` 收到该联想词完整文本。
- [x] 点击/确认右侧联想词后，页面展示 `tv-search-result-grid-panel`，不再停留在搜索主页。
- [x] 从联想词自动搜索进入结果页后，按返回键恢复到原首字母输入串和联想结果列表。
- [x] 用户主动编辑联想词后，仍可通过左侧“搜索”按钮按编辑后的文本搜索。
- [x] `flutter test test/tv_app/tv_search_screen_test.dart` 通过。

## Notes

- 已确认当前 Flutter 实现位于 `lib/tv_app/screens/tv_search_screen.dart`。
- 现有旧测试 `pressing a suggestion fills query without starting search` 需要按新产品行为调整。
- 本次不是 Kotlin TV 端任务，不修改 `re-android/feature-tv-search`。
- 这是轻量交互修复，PRD-only 即可；实现前仍需按 Trellis 流程启动任务。
