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
 * @property deleteFavoriteItem 单条收藏删除函数。
 * @property clearFavorites 全部收藏清空函数。
 */
class TvFavoritesViewModel(
    private val loadFavorites: suspend () -> List<TvVideoCard>,
    private val deleteFavoriteItem: suspend (videoId: String) -> Unit = {},
    private val clearFavorites: suspend () -> Unit = {},
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

    /**
     * 删除单条收藏。
     *
     * @param videoId 视频 ID。
     */
    suspend fun deleteVideo(videoId: String) {
        // 单条删除成功后只移除当前卡片，避免整页重新请求打断焦点。
        deleteFavoriteItem(videoId)
        mutableState.value = mutableState.value.copy(
            videos = mutableState.value.videos.filterNot { it.id == videoId },
        )
    }

    /** 清空全部收藏。 */
    suspend fun clear() {
        // 清空操作对齐 Flutter TV 收藏夹批量管理入口。
        clearFavorites()
        mutableState.value = TvFavoritesUiState()
    }
}
