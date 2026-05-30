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
 */
class TvHistoryViewModel(
    private val loadHistory: suspend () -> List<TvVideoCard>,
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
}
