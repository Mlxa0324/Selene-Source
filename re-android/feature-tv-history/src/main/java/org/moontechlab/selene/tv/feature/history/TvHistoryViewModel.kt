package org.moontechlab.selene.tv.feature.history

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * TV 播放历史界面状态。
 *
 * @property videos 历史视频列表。
 */
data class TvHistoryUiState(
    val videos: List<TvVideoCard> = emptyList(),
)

/**
 * TV 播放历史 ViewModel。
 *
 * @property loadHistory 历史数据加载函数。
 * @property deleteHistoryItem 单条历史删除函数。
 * @property clearHistory 全部历史清空函数。
 */
class TvHistoryViewModel(
    private val loadHistory: suspend () -> List<TvVideoCard>,
    private val deleteHistoryItem: suspend (videoId: String) -> Unit = {},
    private val clearHistory: suspend () -> Unit = {},
) {
    /** 历史内部状态。 */
    private val mutableState = MutableStateFlow(TvHistoryUiState())

    /** 历史公开状态。 */
    val state: StateFlow<TvHistoryUiState> = mutableState

    /** 加载播放历史。 */
    suspend fun load() {
        // 历史页保持独立页面语义，不影响首页当前焦点状态。
        mutableState.value = TvHistoryUiState(videos = loadHistory())
    }

    /**
     * 删除单条播放历史。
     *
     * @param videoId 视频 ID。
     */
    suspend fun deleteVideo(videoId: String) {
        // 先调用外部删除逻辑，成功后再更新当前页面列表。
        deleteHistoryItem(videoId)
        mutableState.value = mutableState.value.copy(
            videos = mutableState.value.videos.filterNot { it.id == videoId },
        )
    }

    /** 清空全部播放历史。 */
    suspend fun clear() {
        // 清空按钮对应 Flutter TV 历史页的批量删除能力。
        clearHistory()
        mutableState.value = TvHistoryUiState()
    }
}
