package org.moontechlab.selene.feature.sourcebrowser

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
import org.moontechlab.selene.core.model.VideoCardModel

@Composable
fun SourceBrowserRoute(
    state: SourceBrowserUiState,
    onSourceSelected: (String) -> Unit,
    onEntryClick: (VideoCardModel) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(text = "资源站浏览", style = MaterialTheme.typography.headlineSmall)
                Text(text = "当前源：${state.selectedSourceName}")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    state.sources.forEach { source ->
                        AssistChip(
                            onClick = { onSourceSelected(source.id) },
                            label = { Text(source.name) },
                        )
                    }
                }
            }
        }
        items(state.entries) { entry ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(text = entry.title, style = MaterialTheme.typography.titleMedium)
                    Text(text = entry.sourceName, style = MaterialTheme.typography.bodyMedium)
                    Button(onClick = { onEntryClick(entry) }) {
                        Text("打开详情")
                    }
                }
            }
        }
    }
}
