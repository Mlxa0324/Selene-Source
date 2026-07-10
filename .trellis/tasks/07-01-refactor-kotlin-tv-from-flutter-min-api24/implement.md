# 实施计划（父任务）

父任务不直接写 feature 代码，只负责搭骨架总纲与子任务创建/验收总控。

## Checklist

1. [ ] 创建 `kotlin-tv/` 目录与 Gradle 根配置（`settings.gradle.kts`、根 `build.gradle.kts`、`gradle/libs.versions.toml`），先只 include `:app:app-tv`。
2. [ ] 创建 6 个子任务（`task.py create ... --parent .trellis/tasks/07-01-refactor-kotlin-tv-from-flutter-min-api24`）：
   - `kotlin-tv-scaffold-core`
   - `kotlin-tv-feature-home`
   - `kotlin-tv-feature-detail`
   - `kotlin-tv-feature-player`
   - `kotlin-tv-feature-search`
   - `kotlin-tv-feature-settings-content`
3. [ ] 在每个子任务 `prd.md` 中写明对 `kotlin-tv-scaffold-core` 的顺序依赖（子任务 2-6 必须等 1 完成）。
4. [ ] 逐一进入子任务规划（brainstorm），子任务复杂的补 `design.md`/`implement.md`。
5. [ ] 子任务 1（scaffold-core）优先启动实现，验证 minSdk 24 + Compose for TV + Media3 兼容性。
6. [ ] 子任务 1 验收通过后，子任务 2-6 可并行或顺序推进（用户/开发者按实际人力决定）。
7. [ ] 全部子任务完成后，父任务做整体验收：跨模块编译、遥控焦点走查、`tv-mode.md` 契约核对。
8. [ ] 更新 `.trellis/spec/frontend/tv-mode.md` 中 Kotlin 专属章节路径引用（`re-android/*` -> `kotlin-tv/*`），保留历史版本作弃用参照说明。
9. [ ] 更新仓库 README / `re-android/README.md`，标注 `re-android` 弃用、`kotlin-tv` 为当前开发方向。

## Validation Commands

```bash
# 子任务 1 完成后执行
./gradlew -p kotlin-tv :app:app-tv:assembleDebug
./gradlew -p kotlin-tv :app:app-tv:testDebugUnitTest

# 全部子任务完成后的整体验收
./gradlew -p kotlin-tv assembleDebug
./gradlew -p kotlin-tv test
rg "后续接入|临时占位|占位|正在开发|后续|placeholder|TODO|骨架" kotlin-tv --glob '!**/build/**'
```

## Review Gates

- Gate 1（子任务 1 完成后）：确认 core 层对外契约冻结，minSdk 24 编译通过无 `NewApi` 阻断性告警。
- Gate 2（每个 feature 子任务完成后）：对照 `.trellis/spec/frontend/tv-mode.md` 对应章节逐条验收，遥控焦点走查通过。
- Gate 3（全部子任务完成后）：父任务整体验收，决定 `re-android` 现存 14 个任务的后续处理（归档/摘录）。

## Rollback Points

- 子任务粒度即回滚粒度，单个子任务出问题不影响其余已验收子任务。
- Gate 1 未通过（兼容性验证失败）时，暂停后续子任务创建，先在 `kotlin-tv-scaffold-core` 内解决兼容性问题。
