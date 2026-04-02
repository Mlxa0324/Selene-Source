package org.moontechlab.selene.core.datastore

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class FavoriteItem(
    val videoId: String,
    val title: String,
    val sourceKey: String = "",
    val sourceName: String,
    val subtitle: String = "",
)

class FavoritesRepository(
    initialItems: List<FavoriteItem> = emptyList(),
) {
    private val itemsState = MutableStateFlow(initialItems)

    val items: StateFlow<List<FavoriteItem>> = itemsState.asStateFlow()

    fun isFavorite(videoId: String): Boolean = itemsState.value.any { it.videoId == videoId }

    fun toggle(item: FavoriteItem) {
        itemsState.value = if (isFavorite(item.videoId)) {
            itemsState.value.filterNot { it.videoId == item.videoId }
        } else {
            listOf(item) + itemsState.value
        }
    }

    fun remove(videoId: String) {
        itemsState.value = itemsState.value.filterNot { it.videoId == videoId }
    }
}

data class PlaybackHistoryItem(
    val videoId: String,
    val title: String,
    val sourceKey: String = "",
    val sourceName: String = "",
    val episodeTitle: String,
    val playUrl: String,
    val progressPercent: Int,
)

class PlaybackHistoryRepository(
    initialItems: List<PlaybackHistoryItem> = emptyList(),
) {
    private val itemsState = MutableStateFlow(initialItems)

    val items: StateFlow<List<PlaybackHistoryItem>> = itemsState.asStateFlow()

    fun record(item: PlaybackHistoryItem) {
        itemsState.value = listOf(item) + itemsState.value.filterNot { it.videoId == item.videoId }
    }

    fun remove(videoId: String) {
        itemsState.value = itemsState.value.filterNot { it.videoId == videoId }
    }
}
