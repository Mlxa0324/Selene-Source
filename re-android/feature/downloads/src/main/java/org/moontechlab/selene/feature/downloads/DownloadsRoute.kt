package org.moontechlab.selene.feature.downloads

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
import org.moontechlab.selene.core.download.DownloadTaskStatus

@Composable
fun DownloadsRoute(
    state: DownloadsUiState,
    onToggleTask: (String) -> Unit,
    onRemoveTask: (String) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(text = "下载管理", style = MaterialTheme.typography.headlineSmall)
                Text(text = "首轮原生版已接入任务分栏、暂停/恢复、删除和离线索引同步。")
            }
        }
        if (state.activeTasks.isNotEmpty()) {
            item {
                Text(text = "进行中", style = MaterialTheme.typography.titleMedium)
            }
        }
        items(state.activeTasks) { task ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(text = task.title, style = MaterialTheme.typography.titleMedium)
                    Text(text = "分片数：${task.segmentCount}  进度：${task.progressPercent}%")
                    Text(text = "状态：${task.status.name}")
                    Button(onClick = { onToggleTask(task.id) }) {
                        Text(if (task.status == DownloadTaskStatus.Downloading) "暂停任务" else "继续下载")
                    }
                    Button(onClick = { onRemoveTask(task.id) }) {
                        Text("删除任务")
                    }
                }
            }
        }
        if (state.completedTasks.isNotEmpty()) {
            item {
                Text(text = "已完成", style = MaterialTheme.typography.titleMedium)
            }
        }
        items(state.completedTasks) { task ->
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(text = task.title, style = MaterialTheme.typography.titleMedium)
                    Text(text = "分片数：${task.segmentCount}  进度：${task.progressPercent}%")
                    Text(text = "状态：${task.status.name}")
                    Button(onClick = { onRemoveTask(task.id) }) {
                        Text("删除记录")
                    }
                }
            }
        }
    }
}
