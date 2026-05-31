package org.moontechlab.selene.tv.feature.detail

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.data.model.TvVideoDetail
import org.moontechlab.selene.tv.core.data.model.TvVideoSource
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest

/**
 * TV 详情页界面状态。
 *
 * @property detail 当前影视详情。
 * @property currentSourceId 当前播放线路 ID。
 * @property currentEpisodeId 当前剧集 ID。
 * @property recommendCards 相关推荐卡片。
 * @property isLoading 是否正在加载详情。
 * @property isLoadingMoreSources 是否正在后台补充播放源。
 * @property errorMessage 详情加载失败文案。
 */
data class TvDetailUiState(
    val detail: TvVideoDetail? = null,
    val currentSourceId: String = "",
    val currentEpisodeId: String = "",
    val recommendCards: List<TvVideoCard> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMoreSources: Boolean = false,
    val errorMessage: String? = null,
) {
    /** 当前选中的播放线路。 */
    val currentSource: TvVideoSource?
        get() = detail?.sources?.firstOrNull { source -> source.id == currentSourceId }

    /** 当前选中的剧集。 */
    val currentEpisode: org.moontechlab.selene.tv.core.data.model.TvEpisode?
        get() = currentSource?.episodes?.firstOrNull { episode -> episode.id == currentEpisodeId }

    /** 当前可下发给播放器的播放请求。 */
    val playbackRequest: PlaybackRequest?
        get() {
            val currentDetail = detail ?: return null
            val source = currentSource ?: return null
            val episode = currentEpisode ?: return null
            if (episode.url.isBlank()) {
                return null
            }
            return PlaybackRequest(
                videoId = currentDetail.id,
                sourceId = source.id,
                episodeId = episode.id,
                url = episode.url,
            )
        }
}

/**
 * TV 详情页 ViewModel。
 *
 * @property loadInitialDetail 首屏详情加载函数。
 * @property loadMoreSources 后台播放源补全函数。
 * @property loadRecommends 推荐加载函数。
 * @property loadResumeEpisodeId 续播剧集读取函数。
 */
class TvDetailViewModel(
    private val loadInitialDetail: suspend (videoId: String) -> TvVideoDetail,
    private val loadMoreSources: suspend (videoId: String, detail: TvVideoDetail) -> List<TvVideoSource> = { _, _ ->
        emptyList()
    },
    private val loadRecommends: suspend (videoId: String, detail: TvVideoDetail) -> List<TvVideoCard> = { _, _ ->
        emptyList()
    },
    private val loadResumeEpisodeId: suspend (videoId: String) -> String? = { null },
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
        mutableState.value = mutableState.value.copy(
            isLoading = true,
            errorMessage = null,
        )
        val initialResult = runCatching { loadInitialDetail(videoId) }
        val initialDetail = initialResult.getOrElse { throwable ->
            // 首屏详情失败时直接进入错误态，避免后台补源覆盖真正失败原因。
            mutableState.value = TvDetailUiState(
                isLoading = false,
                errorMessage = throwable.message ?: "详情加载失败",
            )
            return
        }
        val resumeEpisodeId = loadResumeEpisodeId(videoId)
        val initialSource = initialDetail.firstPlayableSource()
        mutableState.value = TvDetailUiState(
            detail = initialDetail,
            currentSourceId = initialSource?.id.orEmpty(),
            currentEpisodeId = initialSource.episodeIdOrFirst(resumeEpisodeId),
            recommendCards = emptyList(),
            isLoading = false,
            isLoadingMoreSources = true,
        )

        val mergedDetail = runCatching {
            initialDetail.copy(
                sources = mergeSources(
                    currentSources = initialDetail.sources,
                    incomingSources = loadMoreSources(videoId, initialDetail),
                ),
            )
        }.getOrDefault(initialDetail)
        mutableState.value = mutableState.value.copy(
            detail = mergedDetail,
            isLoadingMoreSources = false,
        )

        val recommends = runCatching {
            loadRecommends(videoId, mergedDetail)
        }.getOrDefault(emptyList())
        mutableState.value = mutableState.value.copy(recommendCards = recommends)
    }

    /**
     * 切换播放线路。
     *
     * @param sourceId 播放线路 ID。
     */
    fun selectSource(sourceId: String) {
        val source = mutableState.value.detail?.sources
            ?.firstOrNull { candidate -> candidate.id == sourceId }
            ?: return
        mutableState.value = mutableState.value.copy(
            currentSourceId = source.id,
            currentEpisodeId = source.firstEpisodeIdOrEmpty(),
        )
    }

    /**
     * 切换剧集。
     *
     * @param episodeId 剧集 ID。
     */
    fun selectEpisode(episodeId: String) {
        val hasEpisode = mutableState.value.currentSource?.episodes
            ?.any { episode -> episode.id == episodeId }
            ?: false
        if (!hasEpisode) {
            return
        }
        mutableState.value = mutableState.value.copy(currentEpisodeId = episodeId)
    }

    /**
     * 读取来源下首个剧集 ID。
     *
     * @return 首个剧集 ID；无剧集时返回空字符串。
     */
    private fun TvVideoSource?.firstEpisodeIdOrEmpty(): String {
        // 详情首屏优先选择首个可播放剧集，续播记录命中时由上层覆盖。
        return this?.episodes?.firstOrNull()?.id.orEmpty()
    }

    /**
     * 按续播剧集或首集选择剧集。
     *
     * @param resumeEpisodeId 续播剧集 ID。
     * @return 当前线路内可播放的剧集 ID。
     */
    private fun TvVideoSource?.episodeIdOrFirst(resumeEpisodeId: String?): String {
        if (this == null) {
            return ""
        }
        val resumeEpisode = episodes.firstOrNull { episode -> episode.id == resumeEpisodeId }
        return resumeEpisode?.id ?: firstEpisodeIdOrEmpty()
    }

    /**
     * 获取首个可播放线路。
     *
     * @return 拥有剧集的播放线路。
     */
    private fun TvVideoDetail.firstPlayableSource(): TvVideoSource? {
        return sources.firstOrNull { source -> source.episodes.isNotEmpty() }
    }

    /**
     * 合并播放源并去重。
     *
     * @param currentSources 首屏播放源。
     * @param incomingSources 后台补充播放源。
     * @return 去重后的播放源列表。
     */
    private fun mergeSources(
        currentSources: List<TvVideoSource>,
        incomingSources: List<TvVideoSource>,
    ): List<TvVideoSource> {
        val sourcesById = linkedMapOf<String, TvVideoSource>()
        (currentSources + incomingSources).forEach { source ->
            val existing = sourcesById[source.id]
            if (existing == null) {
                sourcesById[source.id] = source
            } else {
                // 同一线路按剧集 ID 去重追加，避免后台补源打乱当前线路顺序。
                sourcesById[source.id] = existing.copy(
                    episodes = (existing.episodes + source.episodes)
                        .distinctBy { episode -> episode.id.ifBlank { episode.url } },
                )
            }
        }
        return sourcesById.values.toList()
    }
}
