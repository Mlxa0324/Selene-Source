# TV 搜索页推荐区右侧无边距调整

## Goal

搜索页「影片推荐」横向列表右侧 padding 去掉,让末张卡片贴到屏幕右边缘,与首页继续观看区、详情页线路列表/选集列表保持一致的视觉风格。

## Requirements

- 推荐区 `ListView` 右侧 padding 改为 `0`(或仅保留焦点安全间距)
- 加载骨架列表同样处理
- 首页和详情页行为不变

## Acceptance Criteria

- [ ] 搜索页推荐区末张卡片获焦时,焦点边框不被屏幕右边缘裁剪
- [ ] 推荐区列表滚动行为正常
- [ ] 现有搜索页测试通过

## Notes

- 改动文件: `lib/tv_app/screens/tv_search_screen.dart`
- 涉及 `_buildRecommendationList` 和 `_buildRecommendationLoadingList` 的 `EdgeInsets.fromLTRB`
- 轻量任务,PRD-only
