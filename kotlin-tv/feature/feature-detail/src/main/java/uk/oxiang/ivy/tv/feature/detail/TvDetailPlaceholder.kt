package uk.oxiang.ivy.tv.feature.detail

import androidx.compose.runtime.Composable
import androidx.tv.material3.Text

/**
 * TV 详情功能模块占位入口。
 *
 * 具体业务 UI 与交互由 `feature-detail` 子任务落地，本骨架阶段仅保证
 * 模块可被 `settings.gradle.kts` include 并参与多模块编译。
 */
@Composable
fun TvDetailPlaceholder() {
    Text(text = "TvDetailPlaceholder")
}
