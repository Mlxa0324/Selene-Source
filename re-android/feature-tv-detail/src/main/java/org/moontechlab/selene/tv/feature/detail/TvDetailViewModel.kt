package org.moontechlab.selene.tv.feature.detail

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.data.model.TvVideoDetail
import org.moontechlab.selene.tv.core.data.model.TvVideoSource
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState

/**
 * TV 详情页入口上下文。
 *
 * @property source 入口来源标识。
 * @property videoId 入口视频 ID。
 * @property title 入口展示标题。
 * @property searchTitle 标题补源使用的搜索词。
 * @property year 年份过滤条件。
 * @property posterUrl 封面兜底。
 * @property stype 影视类型过滤条件。
 */
data class TvDetailEntry(
    val source: String,
    val videoId: String,
    val title: String = "",
    val searchTitle: String = "",
    val year: String = "",
    val posterUrl: String = "",
    val stype: String = "",
) {
    /** 标题补源最终使用的搜索词。 */
    val resolvedSearchTitle: String
        get() = searchTitle.trim().ifBlank { title.trim() }
}

/**
 * TV 详情页续播记录。
 *
 * @property source 播放记录来源标识。
 * @property videoId 播放记录视频 ID。
 * @property episodeIndex 续播剧集下标，从 0 开始。
 * @property positionMs 续播进度毫秒。
 * @property sourceName 播放线路名称。
 */
data class TvDetailResumeRecord(
    val source: String,
    val videoId: String,
    val episodeIndex: Int = 0,
    val positionMs: Long = 0L,
    val sourceName: String = "",
)

/**
 * TV 详情页 UI 状态。
 *
 * @property detail 当前详情聚合模型。
 * @property currentSourceId 当前选中线路 ID。
 * @property currentEpisodeId 当前选中剧集 ID。
 * @property recommendCards 推荐卡片列表。
 * @property isLoading 兼容旧 UI 的首屏加载标记。
 * @property isInitialLoading 首个可播源尚未确定时为 true。
 * @property isLoadingMoreSources 兼容旧 UI 的后台补源标记。
 * @property isMoreSourcesLoading 后台补源是否仍在进行。
 * @property initialSourcesLoaded 精确源链路是否完成。
 * @property moreSourcesLoaded 标题补源链路是否完成。
 * @property emptyPlaybackCompleted 双路完成后仍无可播线路。
 * @property errorMessage 入口级不可恢复错误。
 * @property isFavorite 收藏状态。
 * @property showResumePrompt 是否展示续播提示。
 * @property resumeEpisodeId 续播剧集 ID。
 * @property resumePositionMs 续播位置毫秒。
 * @property resumeTarget 续播目标 source + id。
 * @property selectedEpisodeGroup 当前选集分组。
 * @property previewPlayerReady 预览播放器是否就绪。
 * @property previewIsPlaying 预览播放器是否播放中。
 * @property previewPositionMs 预览播放器当前位置。
 * @property previewDurationMs 预览播放器总时长。
 * @property previewIsLoading 预览播放器加载态。
 * @property previewNetworkSpeed 预览播放器网速。
 * @property previewPlaybackStarted 预览播放器是否已经有请求。
 */
data class TvDetailUiState(
    val detail: TvVideoDetail? = null,
    val currentSourceId: String = "",
    val currentEpisodeId: String = "",
    val recommendCards: List<TvVideoCard> = emptyList(),
    val isLoading: Boolean = false,
    val isInitialLoading: Boolean = false,
    val isLoadingMoreSources: Boolean = false,
    val isMoreSourcesLoading: Boolean = false,
    val initialSourcesLoaded: Boolean = false,
    val moreSourcesLoaded: Boolean = false,
    val emptyPlaybackCompleted: Boolean = false,
    val errorMessage: String? = null,
    val isFavorite: Boolean = false,
    val showResumePrompt: Boolean = false,
    val resumeEpisodeId: String? = null,
    val resumeEpisodeIndex: Int = 0,
    val resumePositionMs: Long = 0L,
    val resumeTarget: TvDetailResumeTarget? = null,
    val selectedEpisodeGroup: Int = 0,
    val previewPlayerReady: Boolean = false,
    val previewIsPlaying: Boolean = false,
    val previewPositionMs: Long = 0L,
    val previewDurationMs: Long = 0L,
    val previewIsLoading: Boolean = false,
    val previewNetworkSpeed: Long = 0L,
    val previewPlaybackStarted: Boolean = false,
) {
    /** 当前播放线路。 */
    val currentSource: TvVideoSource?
        get() = detail?.sources?.firstOrNull { source -> source.id == currentSourceId }

    /** 当前播放剧集。 */
    val currentEpisode: TvEpisode?
        get() = currentSource?.episodes?.firstOrNull { episode -> episode.id == currentEpisodeId }

    /** 选集分组，每组 20 集。 */
    val episodeGroups: List<List<TvEpisode>>
        get() = currentSource?.episodes?.chunked(EPISODE_GROUP_SIZE).orEmpty()

    /** 当前分组里的剧集列表。 */
    val currentGroupEpisodes: List<TvEpisode>
        get() = episodeGroups.getOrElse(
            selectedEpisodeGroup.coerceIn(0, (episodeGroups.size - 1).coerceAtLeast(0)),
        ) { emptyList() }

    /** 当前可下发给播放器的播放请求。 */
    val playbackRequest: PlaybackRequest?
        get() {
            val currentDetail = detail ?: return null
            val source = currentSource ?: return null
            val episode = currentEpisode ?: return null
            val episodeIndex = source.episodes.indexOfFirst { it.id == episode.id }
                .takeIf { index -> index >= 0 }
                ?: return null
            if (episode.url.isBlank()) {
                // 空 URL 不能进入播放器，避免 WebView 黑屏或重复加载无效地址。
                return null
            }
            return PlaybackRequest(
                videoId = source.videoId.ifBlank { currentDetail.id },
                videoTitle = currentDetail.title,
                sourceId = source.source.ifBlank { source.id },
                episodeId = episode.id,
                episodeIndex = episodeIndex,
                episodeTitle = episode.title,
                url = episode.url,
                startPositionMs = previewPositionMs.takeIf { position -> position > 0L } ?: resumePositionMs,
            )
        }

    private companion object {
        /** 每个选集分组的剧集数量。 */
        const val EPISODE_GROUP_SIZE = 20
    }
}

/**
 * 续播目标线路。
 *
 * @property source 播放来源标识。
 * @property videoId 视频 ID。
 * @property sourceName 线路名称。
 */
data class TvDetailResumeTarget(
    val source: String,
    val videoId: String,
    val sourceName: String = "",
)

/**
 * TV 详情页 ViewModel。
 *
 * @property loadExactSources 精确源加载器。
 * @property loadMoreSources 标题补源加载器。
 * @property loadRecommends 推荐加载器。
 * @property loadResumeRecord 续播记录加载器。
 * @property loadFavoriteState 收藏状态加载器。
 * @property saveFavoriteState 收藏状态保存器。
 * @property playerEngine 预览播放器内核。
 */
class TvDetailViewModel(
    initialEntry: TvDetailEntry? = null,
    private val loadExactSources: suspend (TvDetailEntry) -> List<TvVideoSource> = { emptyList() },
    private val loadMoreSources: suspend (
        TvDetailEntry,
        onIncremental: (List<TvVideoSource>) -> Unit,
    ) -> List<TvVideoSource> = { _, _ -> emptyList() },
    private val loadRecommends: suspend (TvDetailEntry, TvVideoDetail?) -> List<TvVideoCard> = { _, _ -> emptyList() },
    private val loadResumeRecord: suspend (TvDetailEntry) -> TvDetailResumeRecord? = { null },
    private val loadFavoriteState: suspend (TvDetailEntry) -> Boolean = { false },
    private val saveFavoriteState: suspend (TvDetailEntry?, Boolean) -> Unit = { _, _ -> },
    private val playerEngine: PlayerEngine? = null,
) {
    /** 对外暴露的详情页状态。 */
    private val mutableState = MutableStateFlow(TvDetailUiState())
    val state: StateFlow<TvDetailUiState> = mutableState

    /** 当前详情入口，用于收藏保存和旧接口兼容。 */
    private var currentEntry: TvDetailEntry? = initialEntry

    /** 每次 load 递增，防止过期异步回包覆盖新页面。 */
    private var loadSerial: Long = 0L

    /** 预览播放器状态监听任务。 */
    private var previewPlayerJob: Job? = null

    /**
     * 兼容旧路由的详情加载入口。
     *
     * @param videoId 视频 ID。
     */
    suspend fun load(videoId: String) {
        val entry = TvDetailEntry(
            source = currentEntry?.source.orEmpty(),
            videoId = videoId,
            title = currentEntry?.title.orEmpty(),
            searchTitle = currentEntry?.searchTitle.orEmpty(),
            year = currentEntry?.year.orEmpty(),
            posterUrl = currentEntry?.posterUrl.orEmpty(),
            stype = currentEntry?.stype.orEmpty(),
        )
        load(entry)
    }

    /**
     * 加载详情入口。
     *
     * @param entry 详情入口上下文。
     */
    suspend fun load(entry: TvDetailEntry) {
        val serial = ++loadSerial
        currentEntry = entry
        previewPlayerJob?.cancel()
        mutableState.value = TvDetailUiState(
            detail = entry.toBaseDetail(emptyList()),
            isLoading = true,
            isInitialLoading = true,
            isLoadingMoreSources = true,
            isMoreSourcesLoading = true,
        )

        coroutineScope {
            var resumeReady = false
            val resumeDeferred = async {
                runCatching { loadResumeRecord(entry) }.getOrNull()
            }
            val favoriteDeferred = async {
                runCatching { loadFavoriteState(entry) }.getOrDefault(false)
            }
            val exactDeferred = async {
                runCatching { loadExactSources(entry) }
            }
            val moreDeferred = async {
                runCatching {
                    loadMoreSources(entry) { incremental ->
                        if (isActiveSerial(serial)) {
                            mergeSources(
                                serial = serial,
                                incomingSources = incremental,
                                preferIncoming = false,
                                allowResumeFallback = false,
                                allowInitialSelection = resumeReady,
                            )
                        }
                    }
                }
            }

            // 续播记录不阻塞精确源/补源请求启动，但首次选源前必须先拿到最终续播意图。
            val resumeRecord = resumeDeferred.await()
            if (!isActiveSerial(serial)) {
                return@coroutineScope
            }
            applyResumeRecord(serial, resumeRecord)
            resumeReady = true
            maybeSelectInitialSource(
                preferIncoming = true,
                incomingSources = mutableState.value.detail?.sources.orEmpty(),
                allowResumeFallback = false,
            )

            // 精确源先回包时应立即进入首播状态。
            exactDeferred.await()
                .onSuccess { sources ->
                    mergeSources(
                        serial = serial,
                        incomingSources = sources,
                        preferIncoming = true,
                        allowResumeFallback = false,
                    )
                }
                .onFailure {
                    // 精确源失败仅表示本路完成，标题补源仍可继续恢复可播状态。
                }
            markInitialSourcesLoaded(serial)

            // 标题补源结果继续追加，失败也只标记本路完成。
            moreDeferred.await()
                .onSuccess { sources ->
                    mergeSources(
                        serial = serial,
                        incomingSources = sources,
                        preferIncoming = false,
                        allowResumeFallback = true,
                    )
                }
                .onFailure {
                    // 标题补源失败不能清掉精确源已生成的播放请求。
                }
            markMoreSourcesLoaded(serial)

            if (!isActiveSerial(serial)) {
                return@coroutineScope
            }
            mutableState.value = mutableState.value.copy(isFavorite = favoriteDeferred.await())

            // 推荐是次要链路，本阶段不允许影响首播和空态。
            val recommends = runCatching { loadRecommends(entry, mutableState.value.detail) }
                .getOrDefault(emptyList())
            if (isActiveSerial(serial)) {
                mutableState.value = mutableState.value.copy(recommendCards = recommends)
            }
        }
    }

    /**
     * 选择播放线路。
     *
     * @param sourceId 线路 ID。
     */
    fun selectSource(sourceId: String) {
        val state = mutableState.value
        val source = state.detail?.sources?.firstOrNull { it.id == sourceId } ?: return
        val keepEpisodeIndex = state.currentSource
            ?.episodes
            ?.indexOfFirst { episode -> episode.id == state.currentEpisodeId }
            ?.takeIf { index -> index >= 0 }
            ?: 0
        val episodeId = source.episodes
            .getOrNull(keepEpisodeIndex)
            ?.id
            ?: source.firstEpisodeIdOrEmpty()
        mutableState.value = state.copy(
            currentSourceId = source.id,
            currentEpisodeId = episodeId,
            selectedEpisodeGroup = episodeId.toEpisodeGroup(source),
            resumePositionMs = 0L,
            showResumePrompt = false,
            previewPlaybackStarted = true,
            previewPositionMs = 0L,
        )
        startPreviewPlayback()
    }

    /**
     * 选择播放剧集。
     *
     * @param episodeId 剧集 ID。
     */
    fun selectEpisode(episodeId: String) {
        val state = mutableState.value
        val source = state.currentSource ?: return
        if (source.episodes.none { episode -> episode.id == episodeId }) {
            return
        }
        mutableState.value = state.copy(
            currentEpisodeId = episodeId,
            selectedEpisodeGroup = episodeId.toEpisodeGroup(source),
            resumePositionMs = 0L,
            showResumePrompt = false,
            previewPlaybackStarted = true,
            previewPositionMs = 0L,
        )
        startPreviewPlayback()
    }

    /**
     * 选择剧集分组。
     *
     * @param index 分组下标。
     */
    fun selectEpisodeGroup(index: Int) {
        val maxIndex = (mutableState.value.episodeGroups.size - 1).coerceAtLeast(0)
        mutableState.value = mutableState.value.copy(
            selectedEpisodeGroup = index.coerceIn(0, maxIndex),
        )
    }

    /**
     * 切换收藏状态。
     */
    fun toggleFavorite() {
        val state = mutableState.value
        val newFavorite = !state.isFavorite
        mutableState.value = state.copy(isFavorite = newFavorite)
        CoroutineScope(Dispatchers.IO).launch {
            saveFavoriteState(currentEntry, newFavorite)
        }
    }

    /**
     * 关闭续播提示。
     */
    fun dismissResumePrompt() {
        mutableState.value = mutableState.value.copy(showResumePrompt = false)
    }

    /**
     * 根据续播记录恢复播放。
     */
    fun resumeFromRecord() {
        val state = mutableState.value
        val episodeId = state.resumeEpisodeId ?: return
        if (state.currentSource?.episodes?.any { episode -> episode.id == episodeId } == true) {
            mutableState.value = state.copy(
                currentEpisodeId = episodeId,
                showResumePrompt = false,
                selectedEpisodeGroup = episodeId.toEpisodeGroup(state.currentSource),
                previewPlaybackStarted = true,
            )
            startPreviewPlayback()
        } else {
            dismissResumePrompt()
        }
    }

    /**
     * 应用续播记录。
     *
     * @param serial 当前加载序号。
     * @param resumeRecord 续播记录。
     */
    private fun applyResumeRecord(
        serial: Long,
        resumeRecord: TvDetailResumeRecord?,
    ) {
        if (!isActiveSerial(serial) || resumeRecord == null) {
            refreshLoadingState()
            return
        }
        mutableState.value = mutableState.value.copy(
            resumeTarget = TvDetailResumeTarget(
                source = resumeRecord.source,
                videoId = resumeRecord.videoId,
                sourceName = resumeRecord.sourceName,
            ),
            resumeEpisodeIndex = resumeRecord.episodeIndex.coerceAtLeast(0),
            resumePositionMs = resumeRecord.positionMs.coerceAtLeast(0L),
            showResumePrompt = resumeRecord.positionMs > 0L,
        )
        maybeSelectInitialSource(
            preferIncoming = true,
            incomingSources = mutableState.value.detail?.sources.orEmpty(),
            allowResumeFallback = false,
        )
    }

    /**
     * 合并播放源并尝试触发首播。
     *
     * @param serial 当前加载序号。
     * @param incomingSources 新增播放源。
     * @param preferIncoming 无续播时是否优先选中新源。
     * @param allowResumeFallback 是否允许续播未命中时兜底。
     */
    private fun mergeSources(
        serial: Long,
        incomingSources: List<TvVideoSource>,
        preferIncoming: Boolean,
        allowResumeFallback: Boolean,
        allowInitialSelection: Boolean = true,
    ) {
        if (!isActiveSerial(serial) || incomingSources.isEmpty()) {
            refreshLoadingState()
            return
        }
        val state = mutableState.value
        val mergedSources = mergeSourceLists(
            currentSources = state.detail?.sources.orEmpty(),
            incomingSources = incomingSources,
        )
        val detail = state.detail.withSources(mergedSources, state.currentSourceId)
        val refreshedCurrentSource = mergedSources.firstOrNull { source -> source.id == state.currentSourceId }
        val refreshedEpisodeId = refreshedCurrentSource.resolveRefreshedEpisodeId(state.currentEpisodeId)
        mutableState.value = state.copy(
            detail = detail,
            currentEpisodeId = refreshedEpisodeId,
            selectedEpisodeGroup = refreshedEpisodeId.toEpisodeGroup(refreshedCurrentSource),
        )
        if (!allowInitialSelection) {
            refreshLoadingState()
            return
        }
        maybeSelectInitialSource(
            preferIncoming = preferIncoming,
            incomingSources = incomingSources,
            allowResumeFallback = allowResumeFallback,
        )
    }

    /**
     * 尝试解析初始播放源。
     *
     * @param preferIncoming 无续播时是否优先选中新源。
     * @param incomingSources 当前回包播放源。
     * @param allowResumeFallback 是否允许续播兜底。
     */
    private fun maybeSelectInitialSource(
        preferIncoming: Boolean,
        incomingSources: List<TvVideoSource>,
        allowResumeFallback: Boolean,
    ) {
        val state = mutableState.value
        if (state.currentSource != null || state.previewPlaybackStarted) {
            refreshLoadingState()
            return
        }
        val allSources = state.detail?.sources.orEmpty().filter { source -> source.episodes.isNotEmpty() }
        if (allSources.isEmpty()) {
            refreshLoadingState()
            return
        }
        val selectedSource = resolveInitialPlayableSource(
            state = state,
            incomingSources = incomingSources.filter { source -> source.episodes.isNotEmpty() },
            allSources = allSources,
            preferIncoming = preferIncoming,
            allowResumeFallback = allowResumeFallback,
        ) ?: run {
            refreshLoadingState()
            return
        }
        val episodeId = selectedSource.resolveInitialEpisodeId(state)
        mutableState.value = state.copy(
            currentSourceId = selectedSource.id,
            currentEpisodeId = episodeId,
            resumeEpisodeId = episodeId.takeIf { it.isNotBlank() },
            selectedEpisodeGroup = episodeId.toEpisodeGroup(selectedSource),
            previewPlaybackStarted = selectedSource.episodes.isNotEmpty(),
            previewIsLoading = selectedSource.episodes.isNotEmpty(),
        )
        refreshLoadingState()
        startPreviewPlayback()
    }

    /**
     * 标记精确源完成。
     *
     * @param serial 当前加载序号。
     */
    private fun markInitialSourcesLoaded(serial: Long) {
        if (!isActiveSerial(serial)) return
        mutableState.value = mutableState.value.copy(initialSourcesLoaded = true)
        refreshLoadingState()
        checkResumeFallback()
    }

    /**
     * 标记标题补源完成。
     *
     * @param serial 当前加载序号。
     */
    private fun markMoreSourcesLoaded(serial: Long) {
        if (!isActiveSerial(serial)) return
        mutableState.value = mutableState.value.copy(moreSourcesLoaded = true)
        refreshLoadingState()
        checkResumeFallback()
    }

    /**
     * 搜索全部完成后，为未命中的续播目标做兜底。
     */
    private fun checkResumeFallback() {
        val state = mutableState.value
        if (state.currentSource != null || !state.initialSourcesLoaded || !state.moreSourcesLoaded) {
            refreshLoadingState()
            return
        }
        maybeSelectInitialSource(
            preferIncoming = true,
            incomingSources = state.detail?.sources.orEmpty(),
            allowResumeFallback = true,
        )
        refreshLoadingState()
    }

    /**
     * 刷新加载和完成空态。
     */
    private fun refreshLoadingState() {
        val state = mutableState.value
        val hasCurrentSource = state.currentSource != null
        val allLoaded = state.initialSourcesLoaded && state.moreSourcesLoaded
        val hasPlayableSource = state.detail?.sources.orEmpty().any { source -> source.episodes.isNotEmpty() }
        mutableState.value = state.copy(
            isLoading = !hasCurrentSource && !allLoaded,
            isInitialLoading = !hasCurrentSource && !allLoaded,
            isLoadingMoreSources = !state.moreSourcesLoaded,
            isMoreSourcesLoading = !state.moreSourcesLoaded,
            emptyPlaybackCompleted = allLoaded && !hasPlayableSource,
            previewIsLoading = if (allLoaded && !hasCurrentSource) false else state.previewIsLoading,
        )
    }

    /**
     * 启动或刷新预览播放器状态。
     */
    private fun startPreviewPlayback() {
        val engine = playerEngine ?: return
        val request = mutableState.value.playbackRequest ?: return
        previewPlayerJob?.cancel()
        previewPlayerJob = CoroutineScope(Dispatchers.Main).launch {
            mutableState.value = mutableState.value.copy(previewIsLoading = true)
            runCatching { engine.load(request) }
            engine.state.collect { playerState ->
                val state = mutableState.value
                when (playerState) {
                    is PlayerState.Playing -> {
                        val snapshot = playerState.snapshot
                        mutableState.value = state.copy(
                            previewPlayerReady = true,
                            previewIsLoading = false,
                            previewIsPlaying = true,
                            previewPositionMs = snapshot.positionMs,
                            previewDurationMs = snapshot.durationMs,
                            previewNetworkSpeed = snapshot.networkSpeedBytesPerSecond,
                            previewPlaybackStarted = true,
                        )
                    }
                    is PlayerState.Paused -> {
                        val snapshot = playerState.snapshot
                        mutableState.value = state.copy(
                            previewPlayerReady = snapshot != null || state.previewPlayerReady,
                            previewIsLoading = false,
                            previewIsPlaying = false,
                            previewPositionMs = snapshot?.positionMs ?: state.previewPositionMs,
                            previewDurationMs = snapshot?.durationMs ?: state.previewDurationMs,
                        )
                    }
                    is PlayerState.Loading -> {
                        mutableState.value = state.copy(
                            previewIsLoading = true,
                            previewIsPlaying = false,
                        )
                    }
                    is PlayerState.Error -> {
                        mutableState.value = state.copy(
                            previewIsLoading = false,
                            previewIsPlaying = false,
                        )
                    }
                    is PlayerState.Idle -> Unit
                }
            }
        }
    }

    /**
     * 校验异步回包是否仍属于当前加载。
     *
     * @param serial 回包持有的加载序号。
     * @return 仍为当前加载时返回 true。
     */
    private fun isActiveSerial(serial: Long): Boolean {
        return serial == loadSerial
    }

    /**
     * 合并播放源列表。
     *
     * @param currentSources 当前播放源。
     * @param incomingSources 新增播放源。
     * @return 去重合并后的播放源。
     */
    private fun mergeSourceLists(
        currentSources: List<TvVideoSource>,
        incomingSources: List<TvVideoSource>,
    ): List<TvVideoSource> {
        val merged = linkedMapOf<String, TvVideoSource>()
        (currentSources + incomingSources).forEach { source ->
            val key = source.matchKey()
            val existing = merged[key]
            merged[key] = when {
                existing == null -> source
                source.episodes.size > existing.episodes.size -> source
                source.episodes.size == existing.episodes.size -> existing.copy(
                    episodes = (existing.episodes + source.episodes)
                        .distinctBy { episode -> episode.id.ifBlank { episode.url } },
                )
                else -> existing
            }
        }
        return merged.values.toList()
    }

    /**
     * 解析初始播放源。
     *
     * @param state 当前状态。
     * @param incomingSources 当前回包播放源。
     * @param allSources 全量播放源。
     * @param preferIncoming 无续播时是否优先选中新源。
     * @param allowResumeFallback 是否允许续播兜底。
     * @return 可用于首播的播放源。
     */
    private fun resolveInitialPlayableSource(
        state: TvDetailUiState,
        incomingSources: List<TvVideoSource>,
        allSources: List<TvVideoSource>,
        preferIncoming: Boolean,
        allowResumeFallback: Boolean,
    ): TvVideoSource? {
        val target = state.resumeTarget
        if (target == null) {
            // 无续播目标时，Flutter 会让首个可播结果立即起播。
            return if (preferIncoming && incomingSources.isNotEmpty()) {
                incomingSources.first()
            } else {
                allSources.first()
            }
        }
        allSources.firstOrNull { source -> source.matchesResumeTarget(target) }?.let { return it }
        allSources.firstOrNull { source -> source.matchesResumeSource(target) }?.let { return it }
        allSources.firstOrNull { source -> source.matchesResumeSourceName(target) }?.let { return it }
        if (!allowResumeFallback) {
            // 搜索未结束前不抢播非目标源，避免继续观看从错误线路 0 秒开始。
            return null
        }
        val wantedEpisodeIndex = state.resumeEpisodeIndex()
        return allSources.firstOrNull { source -> wantedEpisodeIndex in source.episodes.indices }
            ?: allSources.maxByOrNull { source -> source.episodes.size }
    }

    /**
     * 根据续播状态解析初始剧集。
     *
     * @param state 当前状态。
     * @return 剧集 ID。
     */
    private fun TvVideoSource.resolveInitialEpisodeId(state: TvDetailUiState): String {
        val resumeIndex = state.resumeEpisodeIndex()
        return episodes.getOrNull(resumeIndex)?.id ?: firstEpisodeIdOrEmpty()
    }

    /**
     * 刷新当前剧集 ID。
     *
     * @param currentEpisodeId 当前剧集 ID。
     * @return 新线路仍可用的剧集 ID。
     */
    private fun TvVideoSource?.resolveRefreshedEpisodeId(currentEpisodeId: String): String {
        if (this == null) return currentEpisodeId
        return episodes.firstOrNull { episode -> episode.id == currentEpisodeId }?.id
            ?: episodes.firstOrNull()?.id.orEmpty()
    }

    /**
     * 解析续播剧集下标。
     *
     * @return 续播剧集下标，从 0 开始。
     */
    private fun TvDetailUiState.resumeEpisodeIndex(): Int {
        val episodeId = resumeEpisodeId.orEmpty()
        val matchedIndex = currentSource?.episodes?.indexOfFirst { episode -> episode.id == episodeId } ?: -1
        if (matchedIndex >= 0) return matchedIndex
        return resumeEpisodeIndex.coerceAtLeast(0)
    }

    /**
     * 获取线路第一集 ID。
     *
     * @return 第一集 ID。
     */
    private fun TvVideoSource.firstEpisodeIdOrEmpty(): String {
        return episodes.firstOrNull()?.id.orEmpty()
    }

    /**
     * 计算剧集所属分组。
     *
     * @param source 播放线路。
     * @return 剧集分组下标。
     */
    private fun String.toEpisodeGroup(source: TvVideoSource?): Int {
        if (source == null) return 0
        val episodeIndex = source.episodes.indexOfFirst { episode -> episode.id == this }
        return if (episodeIndex >= 0) episodeIndex / EPISODE_GROUP_SIZE else 0
    }

    /**
     * 构建播放源匹配 key。
     *
     * @return `source::videoId` key。
     */
    private fun TvVideoSource.matchKey(): String {
        val resolvedSource = source.ifBlank { id.substringBefore("::", id) }
        val resolvedVideoId = videoId.ifBlank { id.substringAfter("::", "") }
        return if (resolvedSource.isNotBlank() && resolvedVideoId.isNotBlank()) {
            "$resolvedSource::$resolvedVideoId"
        } else {
            id
        }
    }

    /**
     * 判断线路是否命中续播精确目标。
     *
     * @param target 续播目标。
     * @return source + id 都一致时返回 true。
     */
    private fun TvVideoSource.matchesResumeTarget(target: TvDetailResumeTarget): Boolean {
        return source == target.source && videoId == target.videoId
    }

    /**
     * 判断线路是否命中续播来源。
     *
     * @param target 续播目标。
     * @return 来源一致时返回 true。
     */
    private fun TvVideoSource.matchesResumeSource(target: TvDetailResumeTarget): Boolean {
        return target.source.isNotBlank() && source == target.source
    }

    /**
     * 判断线路名是否命中续播记录。
     *
     * @param target 续播目标。
     * @return 线路名一致时返回 true。
     */
    private fun TvVideoSource.matchesResumeSourceName(target: TvDetailResumeTarget): Boolean {
        val wantedName = target.sourceName.normalizedResumeKey()
        if (wantedName.isBlank()) return false
        return name.normalizedResumeKey() == wantedName
    }

    /**
     * 归一化续播线路名。
     *
     * @return 去空白小写后的匹配 key。
     */
    private fun String.normalizedResumeKey(): String {
        return replace(Regex("\\s+"), "").lowercase()
    }

    /**
     * 构造基础详情模型。
     *
     * @param sources 播放源列表。
     * @return 详情模型。
     */
    private fun TvDetailEntry?.toBaseDetail(sources: List<TvVideoSource>): TvVideoDetail? {
        val entry = this ?: return null
        val primarySource = sources.firstOrNull()
        return TvVideoDetail(
            id = primarySource?.videoId?.takeIf { it.isNotBlank() } ?: entry.videoId,
            title = entry.title.ifBlank { entry.resolvedSearchTitle }.ifBlank { entry.videoId },
            description = "",
            posterUrl = entry.posterUrl,
            year = entry.year,
            sourceName = primarySource?.name.orEmpty(),
            sources = sources,
        )
    }

    /**
     * 用播放源刷新详情摘要。
     *
     * @param sources 最新播放源列表。
     * @param currentSourceId 当前源 ID。
     * @return 刷新后的详情模型。
     */
    private fun TvVideoDetail?.withSources(
        sources: List<TvVideoSource>,
        currentSourceId: String,
    ): TvVideoDetail? {
        val baseDetail = this ?: currentEntry.toBaseDetail(sources) ?: return null
        val primarySource = sources.firstOrNull { source -> source.id == currentSourceId }
            ?: sources.firstOrNull()
        return baseDetail.copy(
            id = primarySource?.videoId?.takeIf { videoId -> videoId.isNotBlank() } ?: baseDetail.id,
            sourceName = primarySource?.name.orEmpty().ifBlank { baseDetail.sourceName },
            sources = sources,
        )
    }

    private companion object {
        /** 选集分组大小。 */
        const val EPISODE_GROUP_SIZE = 20
    }
}
