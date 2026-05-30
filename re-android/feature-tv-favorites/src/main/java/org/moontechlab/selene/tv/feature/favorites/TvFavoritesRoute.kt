package org.moontechlab.selene.tv.feature.favorites

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
 * TV 收藏夹路由。
 *
 * @param state 收藏夹界面状态。
 */
@Composable
fun TvFavoritesRoute(
    state: TvFavoritesUiState = TvFavoritesUiState(),
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(36.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "收藏夹 (${state.videos.size})",
            style = MaterialTheme.typography.headlineMedium,
        )
    }
}
