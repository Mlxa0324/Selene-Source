package org.moontechlab.selene.feature.favorites

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.common.DefaultCoroutineDispatchers
import org.moontechlab.selene.core.datastore.FavoriteItem
import org.moontechlab.selene.core.datastore.FavoritesRepository

data class FavoritesUiState(
    val items: List<FavoriteItem> = emptyList(),
)

class FavoritesViewModel(
    private val repository: FavoritesRepository = FavoritesRepository(
        initialItems = listOf(
            FavoriteItem(videoId = "favorite-001", title = "三体", sourceName = "非凡影视", subtitle = "科幻 / 已收藏"),
            FavoriteItem(videoId = "favorite-002", title = "凡人修仙传", sourceName = "动漫港", subtitle = "动画 / 已收藏"),
        ),
    ),
    private val dispatchers: CoroutineDispatchers = DefaultCoroutineDispatchers,
) : ViewModel() {
    private val state = MutableStateFlow(FavoritesUiState())

    val uiState: StateFlow<FavoritesUiState> = state.asStateFlow()

    init {
        viewModelScope.launch(dispatchers.main) {
            repository.items.collect { items ->
                state.value = FavoritesUiState(items = items)
            }
        }
    }

    fun toggleFavorite(videoId: String) {
        repository.remove(videoId)
    }
}
