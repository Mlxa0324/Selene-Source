package org.moontechlab.selene.tv.feature.history

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * TV 播放历史路由。
 *
 * @param state 播放历史界面状态。
 */
@Composable
fun TvHistoryRoute(
    state: TvHistoryUiState = TvHistoryUiState(),
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(36.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "播放历史 (${state.videos.size})",
            style = MaterialTheme.typography.headlineMedium,
        )
    }
}
