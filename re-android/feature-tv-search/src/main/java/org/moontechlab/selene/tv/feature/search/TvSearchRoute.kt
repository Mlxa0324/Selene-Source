package org.moontechlab.selene.tv.feature.search

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
 * TV 搜索路由。
 *
 * @param state 搜索界面状态。
 */
@Composable
fun TvSearchRoute(
    state: TvSearchUiState = TvSearchUiState(),
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 36.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = "搜索",
            style = MaterialTheme.typography.headlineMedium,
        )
        // 首期先展示搜索历史和分组标题，后续替换为遥控器键盘与卡片列表。
        Text(text = "历史：${state.searchHistory.joinToString()}")
        state.resultGroups.forEach { group ->
            Text(text = "${group.title} (${group.videos.size})")
        }
    }
}
