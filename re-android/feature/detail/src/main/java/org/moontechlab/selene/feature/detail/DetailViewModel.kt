package org.moontechlab.selene.feature.detail

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.common.DefaultCoroutineDispatchers
import org.moontechlab.selene.core.datastore.FavoriteItem
import org.moontechlab.selene.core.datastore.FavoritesRepository
import org.moontechlab.selene.core.model.VideoDetail

data class DetailUiState(
    val detail: VideoDetail? = null,
    val isLoading: Boolean = false,
    val isFavorite: Boolean = false,
)

class DetailViewModel(
    private val repository: DetailRepository = DetailRepository(),
    private val favoritesRepository: FavoritesRepository = FavoritesRepository(),
    private val dispatchers: CoroutineDispatchers = DefaultCoroutineDispatchers,
) : ViewModel() {
    private val mutableUiState = MutableStateFlow(DetailUiState())
    val uiState: StateFlow<DetailUiState> = mutableUiState.asStateFlow()

    fun load(
        id: String,
        sourceKey: String = "",
    ) {
        if (id.isBlank()) return
        mutableUiState.value = mutableUiState.value.copy(isLoading = true)
        viewModelScope.launch(dispatchers.io) {
            val detail = repository.loadDetail(id = id, sourceKey = sourceKey)
            mutableUiState.value = DetailUiState(
                detail = detail,
                isLoading = false,
                isFavorite = favoritesRepository.isFavorite(detail.id),
            )
        }
    }

    fun toggleFavorite() {
        val detail = mutableUiState.value.detail ?: return
        favoritesRepository.toggle(
            FavoriteItem(
                videoId = detail.id,
                title = detail.title,
                sourceKey = detail.sourceKey,
                sourceName = detail.sourceName,
                subtitle = detail.typeName ?: detail.year ?: "详情页收藏",
            ),
        )
        mutableUiState.value = mutableUiState.value.copy(
            isFavorite = favoritesRepository.isFavorite(detail.id),
        )
    }
}
