# 修复 Kotlin TV 详情页无数据执行清单

- [x] 补 `TvDetailRepositoryTest` 红灯：精确详情失败后按标题搜索回填详情。
- [x] 补 `TvDetailRepositoryTest` 红灯：`douban` / 空来源入口直接标题补源。
- [x] 补匹配测试：标题归一化，年份缺失允许匹配，重复线路保留更多剧集。
- [x] 补容器层测试：精确详情返回空集数时继续标题补源并生成播放请求。
- [x] 在 `TvDetailRepository` 增加标题补源详情构建能力。
- [x] 调整 `TvAppContainer.createDetailViewModel()` 的初始详情加载逻辑，先精确后补源。
- [x] 运行 `:core-data:testDebugUnitTest`、`:feature-tv-detail:testDebugUnitTest`、`:app-tv:testDebugUnitTest` 相关测试。
- [x] 更新任务记录和验证结果。

## Validation Result

- 通过：`./re-android/gradlew -p re-android :core-data:testDebugUnitTest --tests org.moontechlab.selene.tv.core.data.repository.TvDetailRepositoryTest :app-tv:testDebugUnitTest --tests org.moontechlab.selene.tv.app.TvAppContainerTest`
- 通过：`./re-android/gradlew -p re-android :core-data:testDebugUnitTest :feature-tv-detail:testDebugUnitTest :app-tv:testDebugUnitTest`
- 通过：`git diff --check -- re-android/core-data/src/main/java/org/moontechlab/selene/tv/core/data/repository/TvDetailRepository.kt re-android/app-tv/src/main/java/org/moontechlab/selene/tv/app/TvAppContainer.kt re-android/core-data/src/test/java/org/moontechlab/selene/tv/core/data/repository/TvDetailRepositoryTest.kt re-android/app-tv/src/test/java/org/moontechlab/selene/tv/app/TvAppContainerTest.kt`

## Spec Review

- 已核对 `.trellis/spec/frontend/tv-mode.md` 中“TV 详情页加载错误契约”，现有规范已经要求精确源失败后继续等待标题补源；本次不需要新增规范。
