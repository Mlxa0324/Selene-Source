package org.moontechlab.selene.feature.detail

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.moontechlab.selene.core.model.VideoEpisode

@Composable
fun DetailRoute(
    state: DetailUiState,
    onPlayEpisode: (String, String, String, String, VideoEpisode) -> Unit,
    onToggleFavorite: () -> Unit,
) {
    val detail = state.detail
    if (detail == null) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.Center,
        ) {
            Text(if (state.isLoading) "详情加载中..." else "暂无详情")
        }
        return
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(text = detail.title)
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = detail.description)
            Spacer(modifier = Modifier.height(8.dp))
            Button(onClick = onToggleFavorite) {
                Text(if (state.isFavorite) "取消收藏" else "加入收藏")
            }
        }
        items(detail.episodes) { episode ->
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(text = episode.title)
                Spacer(modifier = Modifier.height(4.dp))
                Button(
                    onClick = {
                        onPlayEpisode(
                            detail.id,
                            detail.title,
                            detail.sourceKey,
                            detail.sourceName,
                            episode,
                        )
                    },
                ) {
                    Text("播放")
                }
            }
        }
    }
}
