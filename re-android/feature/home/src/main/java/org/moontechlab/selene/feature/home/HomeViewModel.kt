package org.moontechlab.selene.feature.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.common.DefaultCoroutineDispatchers
import org.moontechlab.selene.core.datastore.FavoriteItem
import org.moontechlab.selene.core.datastore.FavoritesRepository
import org.moontechlab.selene.core.datastore.PlaybackHistoryItem
import org.moontechlab.selene.core.datastore.PlaybackHistoryRepository

data class HomeUiState(
    val title: String = "首页",
    val continueWatching: List<PlaybackHistoryItem> = emptyList(),
    val favorites: List<FavoriteItem> = emptyList(),
)

class HomeViewModel(
    private val favoritesRepository: FavoritesRepository = FavoritesRepository(),
    private val historyRepository: PlaybackHistoryRepository = PlaybackHistoryRepository(),
    private val dispatchers: CoroutineDispatchers = DefaultCoroutineDispatchers,
) : ViewModel() {
    private val state = MutableStateFlow(HomeUiState())

    val uiState: StateFlow<HomeUiState> = state.asStateFlow()

    init {
        viewModelScope.launch(dispatchers.main) {
            combine(
                favoritesRepository.items,
                historyRepository.items,
            ) { favorites, history ->
                HomeUiState(
                    continueWatching = history.take(4),
                    favorites = favorites.take(4),
                )
            }.collect { state.value = it }
        }
    }
}
