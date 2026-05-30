package org.moontechlab.selene.tv.feature.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * TV 首页路由。
 *
 * @param state 首页界面状态。
 */
@Composable
fun TvHomeRoute(
    state: TvHomeUiState = TvHomeUiState(),
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 36.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = "IvyTV",
            style = MaterialTheme.typography.headlineMedium,
        )
        // 首期先展示分区标题，后续替换为横向影视卡片列表。
        state.sections.forEach { section ->
            Text(
                text = section.title,
                style = MaterialTheme.typography.titleMedium,
            )
        }
    }
}
