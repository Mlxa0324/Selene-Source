package org.moontechlab.selene.feature.player

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun PlayerRoute(
    state: PlayerUiState,
    onPlay: () -> Unit,
    onPause: () -> Unit,
    onToggleFavorite: () -> Unit,
    onAddDownload: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text(text = state.title)
        Spacer(modifier = Modifier.height(8.dp))
        Text(text = state.currentUrl.ifBlank { "尚未装载播放地址" })
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = if (state.isPlaying) onPause else onPlay) {
            Text(if (state.isPlaying) "暂停" else "播放")
        }
        Spacer(modifier = Modifier.height(8.dp))
        Button(onClick = onToggleFavorite) {
            Text(if (state.isFavorite) "取消收藏" else "加入收藏")
        }
        Spacer(modifier = Modifier.height(8.dp))
        Button(onClick = onAddDownload) {
            Text(if (state.hasDownloadTask) "已加入下载" else "加入下载")
        }
    }
}
