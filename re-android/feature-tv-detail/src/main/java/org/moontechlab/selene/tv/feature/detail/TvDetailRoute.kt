package org.moontechlab.selene.tv.feature.detail

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
 * TV 详情页路由。
 *
 * @param state 详情页界面状态。
 */
@Composable
fun TvDetailRoute(
    state: TvDetailUiState = TvDetailUiState(),
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 36.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = state.detail?.title ?: "详情",
            style = MaterialTheme.typography.headlineMedium,
        )
        Text(text = "当前线路：${state.currentSourceId}")
        Text(text = "当前剧集：${state.currentEpisodeId}")
    }
}
