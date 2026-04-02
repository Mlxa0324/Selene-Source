package org.moontechlab.selene.feature.favorites

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
import org.moontechlab.selene.core.datastore.FavoriteItem

@Composable
fun FavoritesRoute(
    state: FavoritesUiState,
    onOpenDetail: (FavoriteItem) -> Unit,
    onToggleFavorite: (String) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(text = "我的收藏", style = MaterialTheme.typography.headlineSmall)
        }
        items(state.items) { item ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(text = item.title, style = MaterialTheme.typography.titleMedium)
                    Text(text = item.subtitle, style = MaterialTheme.typography.bodyMedium)
                    Button(onClick = { onOpenDetail(item) }) {
                        Text("打开详情")
                    }
                    Button(onClick = { onToggleFavorite(item.videoId) }) {
                        Text("取消收藏")
                    }
                }
            }
        }
    }
}
