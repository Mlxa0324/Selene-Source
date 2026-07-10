# 实施计划：Kotlin TV 设置与历史收藏直播

## Preconditions

- `07-01-kotlin-tv-scaffold-core` 已验收通过，`core-common`/`core-design`/`core-player` 契约已冻结。

## Checklist

1. [ ] `gradle/libs.versions.toml` 新增 NanoHTTPD、ZXing 依赖，`feature-settings/build.gradle.kts` 引入。
2. [ ] 历史/收藏共用列表：实现 `TvVideoLibraryRoute` + `TvVideoLibraryViewModel`（load/delete/clear），再包 `TvHistoryRoute`/`TvFavoritesRoute` 薄壳。
3. [ ] 直播占位页：`TvLiveRoute` 展示"正在开发"文案，接收 `contentFocusRequester`。
4. [ ] 设置页服务器配置分区：字段浏览/编辑态切换、保存动作接入 `core-common` 会话仓库。
5. [ ] 设置页图片与弹幕分区：图片代理 4 选项、去广告开关、弹幕地址字段、跳转弹幕手动匹配入口。
6. [ ] 弹幕手动匹配面板：`TvDanmakuMatchRoute` + `TvDanmakuMatchViewModel`，删字/清空/恢复/搜索/选集回调。
7. [ ] 设置页缓存管理分区：占用展示、清除按钮，接入 core-common 缓存服务。
8. [ ] 设置页外观分区：三主题色选项切换与保存。
9. [ ] 手机扫码桥接：`TvMobileSettingsDraft` 编解码 -> `TvMobileSettingsBridgeServer`(NanoHTTPD) -> `TvMobileSettingsBridgeSession`(端口探测/重生成/关闭) -> ZXing 二维码渲染 -> 设置页 UI 接线。
10. [ ] 焦点契约补齐：顶部导航下探、空态/加载态/列表态可聚焦目标，对齐 `06-24-govern-kotlin-tv-focus-navigation` 已有契约。
11. [ ] 补齐单元测试（见 design.md Testing Strategy）。

## Validation Commands

```bash
./gradlew -p kotlin-tv :feature:feature-settings:testDebugUnitTest
./gradlew -p kotlin-tv :feature:feature-content:testDebugUnitTest
./gradlew -p kotlin-tv :feature:feature-settings:lintDebug :feature:feature-content:lintDebug
```

## Review Gates

- Gate A（步骤 2-3 完成后）：历史/收藏/直播基础列表可用，先验收这部分再进入设置页。
- Gate B（步骤 4-8 完成后）：设置页四分区（除手机扫码桥接）全部可用并联调保存动作。
- Gate C（步骤 9 完成后）：手机扫码桥接端到端验证——真机/模拟器同局域网扫码提交表单，TV 端表单正确回填。

## Rollback Points

- 手机扫码桥接（步骤 9）失败风险最高，若卡住可先按 design.md Rollback 策略降级为占位态，不阻塞其余分区验收。
- 历史/收藏共用列表组件如与 scaffold-core 冻结的 core-design 组件契约不匹配，回退到该步骤重新对齐契约，不影响已完成的设置页分区。
