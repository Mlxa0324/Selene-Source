package org.moontechlab.selene.tv.feature.player

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

/**
 * TV 全屏播放器路由。
 *
 * @param viewModel 播放器 ViewModel。
 */
@Composable
fun TvPlayerRoute(
    viewModel: TvPlayerViewModel = TvPlayerViewModel(),
) {
    val state by viewModel.state.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(36.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        Text(
            text = "全屏播放",
            style = MaterialTheme.typography.headlineMedium,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(onClick = { viewModel.openMenu(PLAYER_MENU_PLAYLIST) }) {
                Text(text = PLAYER_MENU_PLAYLIST)
            }
            Button(
                modifier = Modifier.testTag("tv-player-menu-other"),
                onClick = { viewModel.openMenu(PLAYER_MENU_OTHER) },
            ) {
                Text(text = PLAYER_MENU_OTHER)
            }
        }
        if (state.isMenuVisible && state.selectedTopMenu == PLAYER_MENU_OTHER) {
            // 其它菜单首期只暴露内核切换入口，后续继续接片头片尾和弹幕项。
            Text(
                text = state.selectedOtherMenuItem,
                style = MaterialTheme.typography.titleMedium,
            )
        }
    }
}
