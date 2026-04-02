package org.moontechlab.selene.feature.history

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.common.DefaultCoroutineDispatchers
import org.moontechlab.selene.core.datastore.PlaybackHistoryItem
import org.moontechlab.selene.core.datastore.PlaybackHistoryRepository

data class HistoryUiState(
    val items: List<PlaybackHistoryItem> = emptyList(),
)

class HistoryViewModel(
    private val repository: PlaybackHistoryRepository = PlaybackHistoryRepository(
        initialItems = listOf(
            PlaybackHistoryItem(
                videoId = "history-001",
                title = "三体",
                episodeTitle = "第4集",
                playUrl = "https://example.com/santi-4.m3u8",
                progressPercent = 67,
            ),
            PlaybackHistoryItem(
                videoId = "history-002",
                title = "流浪地球 2",
                episodeTitle = "正片",
                playUrl = "https://example.com/wandering-earth-2.m3u8",
                progressPercent = 94,
            ),
        ),
    ),
    private val dispatchers: CoroutineDispatchers = DefaultCoroutineDispatchers,
) : ViewModel() {
    private val state = MutableStateFlow(HistoryUiState())

    val uiState: StateFlow<HistoryUiState> = state.asStateFlow()

    init {
        viewModelScope.launch(dispatchers.main) {
            repository.items.collect { items ->
                state.value = HistoryUiState(items = items)
            }
        }
    }

    fun remove(historyId: String) {
        repository.remove(historyId)
    }
}
