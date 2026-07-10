package uk.oxiang.ivy.tv.feature.content

import androidx.compose.runtime.Composable
import androidx.tv.material3.Text

/**
 * TV 内容库功能模块占位入口。
 *
 * 具体业务 UI 与交互由 `feature-content` 子任务落地，本骨架阶段仅保证
 * 模块可被 `settings.gradle.kts` include 并参与多模块编译。
 */
@Composable
fun TvContentPlaceholder() {
    Text(text = "TvContentPlaceholder")
}
