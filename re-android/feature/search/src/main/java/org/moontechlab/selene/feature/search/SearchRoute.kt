package org.moontechlab.selene.feature.search

import androidx.compose.foundation.clickable
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
import androidx.compose.material3.Card
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.moontechlab.selene.core.model.VideoCardModel

@Composable
fun SearchRoute(
    state: SearchUiState,
    onQueryChanged: (String) -> Unit,
    onSearch: () -> Unit,
    onResultClick: (VideoCardModel) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        OutlinedTextField(
            value = state.query,
            onValueChange = onQueryChanged,
            modifier = Modifier.fillMaxWidth(),
            label = { Text("搜索影视") },
            singleLine = true,
        )
        Button(
            onClick = onSearch,
            enabled = state.query.isNotBlank() && !state.isLoading,
        ) {
            Text(if (state.isLoading) "搜索中..." else "搜索")
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(state.results) { result ->
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onResultClick(result) },
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Text(text = result.title)
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(text = "${result.sourceName} · ${result.sourceKey}")
                        if (!result.year.isNullOrBlank() || !result.subtitle.isNullOrBlank()) {
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(text = listOfNotNull(result.year, result.subtitle).joinToString(" · "))
                        }
                    }
                }
            }
        }
    }
}
