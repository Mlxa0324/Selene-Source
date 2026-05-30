package org.moontechlab.selene.tv.feature.detail

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.data.model.TvVideoDetail
import org.moontechlab.selene.tv.core.data.model.TvVideoSource

/**
 * TV 详情页界面状态。
 *
 * @property detail 当前影视详情。
 * @property currentSourceId 当前播放线路 ID。
 * @property currentEpisodeId 当前剧集 ID。
 * @property recommendCards 相关推荐卡片。
 * @property isLoading 是否正在加载详情。
 */
data class TvDetailUiState(
    val detail: TvVideoDetail? = null,
    val currentSourceId: String = "",
    val currentEpisodeId: String = "",
    val recommendCards: List<TvVideoCard> = emptyList(),
    val isLoading: Boolean = false,
)

/**
 * TV 详情页 ViewModel。
 *
 * @property loadDetail 详情数据加载函数。
 */
class TvDetailViewModel(
    private val loadDetail: suspend (videoId: String) -> TvVideoDetail,
) {
    /** 详情内部状态。 */
    private val mutableState = MutableStateFlow(TvDetailUiState())

    /** 详情公开状态。 */
    val state: StateFlow<TvDetailUiState> = mutableState

    /**
     * 加载影视详情。
     *
     * @param videoId 影视 ID。
     */
    suspend fun load(videoId: String) {
        mutableState.value = mutableState.value.copy(isLoading = true)
        val detail = loadDetail(videoId)
        val currentSource = detail.sources.firstOrNull { source -> source.episodes.isNotEmpty() }
        mutableState.value = TvDetailUiState(
            detail = detail,
            currentSourceId = currentSource?.id.orEmpty(),
            currentEpisodeId = currentSource.firstEpisodeIdOrEmpty(),
            recommendCards = emptyList(),
            isLoading = false,
        )
    }

    /**
     * 读取来源下首个剧集 ID。
     *
     * @return 首个剧集 ID；无剧集时返回空字符串。
     */
    private fun TvVideoSource?.firstEpisodeIdOrEmpty(): String {
        // 详情首屏优先选择首个可播放剧集，后续再接续播记录修正初始集数。
        return this?.episodes?.firstOrNull()?.id.orEmpty()
    }
}
