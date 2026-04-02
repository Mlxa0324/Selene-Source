package org.moontechlab.selene.feature.history

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.moontechlab.selene.core.datastore.PlaybackHistoryItem

@Composable
fun HistoryRoute(
    state: HistoryUiState,
    onResumePlayback: (PlaybackHistoryItem) -> Unit,
    onRemove: (String) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(text = "播放历史", style = MaterialTheme.typography.headlineSmall)
        }
        items(state.items) { item ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(text = item.title, style = MaterialTheme.typography.titleMedium)
                    Text(
                        text = "${item.episodeTitle}  已观看 ${item.progressPercent}%",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Button(onClick = { onResumePlayback(item) }) {
                        Text("继续播放")
                    }
                    Button(onClick = { onRemove(item.videoId) }) {
                        Text("删除记录")
                    }
                }
            }
        }
    }
}
