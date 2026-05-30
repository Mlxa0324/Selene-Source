package org.moontechlab.selene.tv.feature.favorites

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * TV 收藏夹界面状态。
 *
 * @property videos 收藏视频列表。
 */
data class TvFavoritesUiState(
    val videos: List<TvVideoCard> = emptyList(),
)

/**
 * TV 收藏夹 ViewModel。
 *
 * @property loadFavorites 收藏数据加载函数。
 */
class TvFavoritesViewModel(
    private val loadFavorites: suspend () -> List<TvVideoCard>,
) {
    /** 收藏夹内部状态。 */
    private val mutableState = MutableStateFlow(TvFavoritesUiState())

    /** 收藏夹公开状态。 */
    val state: StateFlow<TvFavoritesUiState> = mutableState

    /** 加载收藏夹。 */
    suspend fun load() {
        // 收藏页保持独立页面语义，不复用首页内嵌 tab 状态。
        mutableState.value = TvFavoritesUiState(videos = loadFavorites())
    }
}
