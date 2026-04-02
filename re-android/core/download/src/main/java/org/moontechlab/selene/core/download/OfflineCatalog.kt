package org.moontechlab.selene.core.download

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class OfflineEntry(
    val taskId: String,
    val title: String,
    val localPath: String,
    val playUrl: String,
)

class OfflineCatalog(
    initialEntries: List<OfflineEntry> = emptyList(),
) {
    private val entriesState = MutableStateFlow(initialEntries)

    val entries: StateFlow<List<OfflineEntry>> = entriesState.asStateFlow()

    fun upsert(entry: OfflineEntry) {
        entriesState.value = listOf(entry) + entriesState.value.filterNot { it.taskId == entry.taskId }
    }

    fun remove(taskId: String) {
        entriesState.value = entriesState.value.filterNot { it.taskId == taskId }
    }
}
