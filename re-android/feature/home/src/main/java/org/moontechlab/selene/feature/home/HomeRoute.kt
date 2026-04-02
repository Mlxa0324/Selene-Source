package org.moontechlab.selene.feature.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import org.moontechlab.selene.core.datastore.FavoriteItem
import org.moontechlab.selene.core.datastore.PlaybackHistoryItem

@Composable
fun HomeRoute(
    state: HomeUiState,
    onOpenSearch: () -> Unit,
    onOpenProfile: () -> Unit,
    onOpenFavorite: (FavoriteItem) -> Unit,
    onResumeHistory: (PlaybackHistoryItem) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(text = "Selene 首页", style = MaterialTheme.typography.headlineSmall)
                Button(onClick = onOpenSearch) { Text("开始搜索") }
                Button(onClick = onOpenProfile) { Text("打开设置") }
            }
        }
        item {
            Text(text = "继续观看", style = MaterialTheme.typography.titleLarge)
        }
        if (state.continueWatching.isEmpty()) {
            item { Text("还没有播放历史，去详情页播放一集后会出现在这里。") }
        } else {
            items(state.continueWatching) { item ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(text = item.title)
                        Text(text = "${item.episodeTitle}  已观看 ${item.progressPercent}%")
                        Button(onClick = { onResumeHistory(item) }) { Text("继续播放") }
                    }
                }
            }
        }
        item {
            Spacer(modifier = Modifier.height(4.dp))
            Text(text = "最近收藏", style = MaterialTheme.typography.titleLarge)
        }
        if (state.favorites.isEmpty()) {
            item { Text("还没有收藏内容，播放页点一次收藏就会同步到这里。") }
        } else {
            items(state.favorites) { item ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(text = item.title)
                        Text(text = item.subtitle.ifBlank { item.sourceName })
                        Button(onClick = { onOpenFavorite(item) }) { Text("打开详情") }
                    }
                }
            }
        }
    }
}
