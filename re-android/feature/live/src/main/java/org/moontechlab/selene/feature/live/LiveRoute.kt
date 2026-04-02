package org.moontechlab.selene.feature.live

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun LiveRoute(
    state: LiveUiState,
    onGroupSelected: (String) -> Unit,
    onPlayChannel: (LiveChannelItem) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(text = "直播频道", style = MaterialTheme.typography.headlineSmall)
                Text(text = "按分组切换频道，点击后直接进入播放器。")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    state.groups.forEach { group ->
                        AssistChip(
                            onClick = { onGroupSelected(group) },
                            label = { Text(group) },
                        )
                    }
                }
            }
        }
        items(state.channels) { channel ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(text = channel.name, style = MaterialTheme.typography.titleMedium)
                    Text(text = channel.group, style = MaterialTheme.typography.bodyMedium)
                    Button(onClick = { onPlayChannel(channel) }) {
                        Text("播放直播")
                    }
                }
            }
        }
    }
}
