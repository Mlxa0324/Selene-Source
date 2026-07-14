package org.moontechlab.selene.tv.feature.detail

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.data.model.TvVideoDetail
import org.moontechlab.selene.tv.core.data.model.TvVideoSource
import org.moontechlab.selene.tv.core.player.api.PlaybackIdentity
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState
import org.moontechlab.selene.tv.core.player.api.matchesPlaybackRequest
import org.moontechlab.selene.tv.core.player.api.toPlaybackIdentity

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
 * TV 详情页推荐加载状态。
 */
enum class TvDetailRecommendLoadState {
    /** 尚未安排推荐请求。 */
    Idle,

    /** 推荐请求已经安排，等待延迟或调度执行。 */
    Scheduled,

    /** 推荐请求正在执行。 */
    Loading,

    /** 推荐请求成功并返回非空卡片。 */
    Loaded,

    /** 推荐请求成功但没有可展示卡片。 */
    Empty,

    /** 推荐请求执行失败。 */
    Failed,
}

/**
 * TV 详情页推荐诊断阶段。
 */
enum class TvDetailRecommendDiagnosticStage {
    /** 推荐任务已经安排。 */
    Scheduled,

    /** 推荐加载器开始执行。 */
    Loading,

    /** 推荐身份解析后缺少有效豆瓣 ID。 */
    MissingDoubanId,

    /** 推荐加载成功且结果非空。 */
    Success,

    /** 推荐加载成功但结果为空。 */
    Empty,

    /** 推荐加载失败。 */
    Failure,

    /** 旧详情的异步推荐结果被忽略。 */
    StaleIgnored,
}

/**
 * TV 详情页推荐诊断事件。
 *
 * @property stage 当前诊断阶段。
 * @property entryKey 详情入口稳定标识。
 * @property trigger 推荐调度触发原因。
 * @property count 推荐结果数量。
 * @property message 简洁诊断信息。
 */
data class TvDetailRecommendDiagnostic(
    val stage: TvDetailRecommendDiagnosticStage,
    val entryKey: String,
    val trigger: String = "",
    val count: Int? = null,
    val message: String? = null,
)

/**
 * TV 详情页推荐诊断接收器。
 */
fun interface TvDetailRecommendDiagnosticSink {
    /**
     * 记录单个低频推荐诊断事件。
     *
     * @param event 推荐诊断事件。
     */
    fun record(event: TvDetailRecommendDiagnostic)
}

/**
 * TV 详情页 UI 状态。
 *
 * @property detail 当前详情聚合模型。
 * @property currentSourceId 当前选中线路 ID。
 * @property currentEpisodeId 当前选中剧集 ID。
 * @property recommendCards 推荐卡片列表。
 * @property recommendLoadState 推荐加载状态。
 * @property recommendErrorMessage 推荐加载错误说明。
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
    val recommendLoadState: TvDetailRecommendLoadState = TvDetailRecommendLoadState.Idle,
    val recommendErrorMessage: String? = null,
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
            val playbackUrl = episode.url.trim()
            if (playbackUrl.isBlank()) {
                // 空 URL 不能进入播放器，避免 WebView 黑屏或重复加载无效地址。
                return null
            }
            return PlaybackRequest(
                videoId = source.videoId.ifBlank { currentDetail.id },
                videoTitle = currentDetail.title,
                sourceId = source.source.ifBlank { source.id },
                sourceName = source.name,
                episodeId = episode.id,
                episodeIndex = episodeIndex,
                episodeTitle = episode.title,
                videoYear = currentDetail.year,
                posterUrl = currentDetail.posterUrl,
                totalEpisodes = source.episodes.size,
                searchTitle = currentDetail.title,
                url = playbackUrl,
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
 * 详情页线路加载结果。
 *
 * @property sources 可播放线路。
 * @property detail 详情元数据（简介/年份/封面等），可为空。
 */
data class TvDetailSourcesResult(
    val sources: List<TvVideoSource> = emptyList(),
    val detail: TvVideoDetail? = null,
)

/**
 * TV 详情页 ViewModel。
 *
 * @property loadExactSources 精确详情/线路加载器。
 * @property loadMoreSources 标题补源加载器。
 * @property loadRecommends 推荐加载器。
 * @property loadResumeRecord 续播记录加载器。
 * @property loadFavoriteState 收藏状态加载器。
 * @property saveFavoriteState 收藏状态保存器。
 * @property savePlaybackProgress 预览播放器进度保存器。
 * @property playerEngine 预览播放器内核。
 * @property previewDispatcher 预览播放器协程调度器。
 * @property recommendDiagnosticSink 推荐诊断接收器。
 */
class TvDetailViewModel(
    initialEntry: TvDetailEntry? = null,
    private val loadExactSources: suspend (TvDetailEntry) -> TvDetailSourcesResult = {
        TvDetailSourcesResult()
    },
    private val loadMoreSources: suspend (
        TvDetailEntry,
        onIncremental: (List<TvVideoSource>) -> Unit,
    ) -> TvDetailSourcesResult = { _, _ -> TvDetailSourcesResult() },
    private val loadRecommends: suspend (TvDetailEntry, TvVideoDetail?) -> List<TvVideoCard> = { _, _ -> emptyList() },
    private val loadResumeRecord: suspend (TvDetailEntry) -> TvDetailResumeRecord? = { null },
    private val loadFavoriteState: suspend (TvDetailEntry) -> Boolean = { false },
    private val saveFavoriteState: suspend (TvDetailEntry?, Boolean) -> Unit = { _, _ -> },
    private val savePlaybackProgress: (PlaybackRequest, Long, Long) -> Unit = { _, _, _ -> },
    private val playerEngine: PlayerEngine? = null,
    private val previewDispatcher: CoroutineDispatcher = Dispatchers.Main,
    private val recommendDiagnosticSink: TvDetailRecommendDiagnosticSink = TvDetailRecommendDiagnosticSink { },
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

    /** 详情页数据加载任务，独立于页面组合生命周期，避免全屏返回时中途重跑。 */
    private var detailLoadJob: Job? = null

    /** 当前后台加载目标视频 ID。 */
    private var activeLoadVideoId: String? = null

    /** 详情页后台任务作用域。 */
    private var backgroundScope: CoroutineScope? = null

    /** 当前详情推荐任务。 */
    private var recommendJob: Job? = null

    /** 已经启动推荐调度的详情加载序号。 */
    private var recommendStartedSerial: Long? = null

    /** 当前预览媒体最近一次已保存的续播分段。 */
    private var lastPreviewSavedBucket: Long = UNINITIALIZED_PROGRESS_BUCKET

    /** 当前预览媒体最近一次保存对应的媒体身份。 */
    private var lastPreviewSavedIdentity: PlaybackIdentity? = null

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
     * 按当前详情入口启动加载。
     *
     * 该入口会把任务放到状态机自管作用域里，避免详情页暂时离开组合时整条加载链路被取消。
     *
     * @param videoId 当前视频 ID。
     */
    fun ensureLoaded(videoId: String) {
        if (!shouldStartLoad(videoId)) {
            return
        }
        activeLoadVideoId = videoId.trim()
        detailLoadJob?.cancel()
        detailLoadJob = getOrCreateBackgroundScope().launch {
            load(videoId)
        }
    }

    /**
     * 加载详情入口。
     *
     * @param entry 详情入口上下文。
     */
    suspend fun load(entry: TvDetailEntry) {
        val serial = ++loadSerial
        recommendJob?.cancel()
        recommendJob = null
        recommendStartedSerial = null
        currentEntry = entry
        previewPlayerJob?.cancel()
        lastPreviewSavedIdentity = null
        lastPreviewSavedBucket = UNINITIALIZED_PROGRESS_BUCKET
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

            // 精确源先回包时应立即进入首播状态，并回填接口简介等元数据。
            exactDeferred.await()
                .onSuccess { result ->
                    mergeDetailMetadata(result.detail)
                    mergeSources(
                        serial = serial,
                        incomingSources = result.sources,
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
                .onSuccess { result ->
                    // 精确详情没简介时，用搜索结果里的 desc 兜底。
                    mergeDetailMetadata(result.detail)
                    mergeSources(
                        serial = serial,
                        incomingSources = result.sources,
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
            ?.playableEpisodes()
            ?.indexOfFirst { episode -> episode.id == state.currentEpisodeId }
            ?.takeIf { index -> index >= 0 }
            ?: 0
        val episodeId = source.playableEpisodes()
            .getOrNull(keepEpisodeIndex)
            ?.id
            ?: source.firstPlayableEpisodeIdOrEmpty()
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
        val sanitizedIncomingSources = incomingSources.toPlayableSources()
        if (!isActiveSerial(serial) || sanitizedIncomingSources.isEmpty()) {
            refreshLoadingState()
            return
        }
        val state = mutableState.value
        val mergedSources = mergeSourceLists(
            currentSources = state.detail?.sources.orEmpty(),
            incomingSources = sanitizedIncomingSources,
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
            incomingSources = sanitizedIncomingSources,
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
        val allSources = state.detail?.sources.orEmpty().filter { source -> source.hasPlayableEpisodes() }
        if (allSources.isEmpty()) {
            refreshLoadingState()
            return
        }
        val selectedSource = resolveInitialPlayableSource(
            state = state,
            incomingSources = incomingSources.filter { source -> source.hasPlayableEpisodes() },
            allSources = allSources,
            preferIncoming = preferIncoming,
            allowResumeFallback = allowResumeFallback,
        ) ?: run {
            refreshLoadingState()
            return
        }
        val episodeId = selectedSource.resolveInitialEpisodeId(state)
        val hasPlayableEpisodes = selectedSource.hasPlayableEpisodes()
        mutableState.value = state.copy(
            currentSourceId = selectedSource.id,
            currentEpisodeId = episodeId,
            resumeEpisodeId = episodeId.takeIf { it.isNotBlank() },
            selectedEpisodeGroup = episodeId.toEpisodeGroup(selectedSource),
            previewPlaybackStarted = hasPlayableEpisodes,
            previewIsLoading = hasPlayableEpisodes,
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
        val hasPlayableSource = state.detail?.sources.orEmpty().any { source -> source.hasPlayableEpisodes() }
        val refreshedState = state.copy(
            isLoading = !hasCurrentSource && !allLoaded,
            isInitialLoading = !hasCurrentSource && !allLoaded,
            isLoadingMoreSources = !state.moreSourcesLoaded,
            isMoreSourcesLoading = !state.moreSourcesLoaded,
            emptyPlaybackCompleted = allLoaded && !hasPlayableSource,
            previewIsLoading = if (allLoaded && !hasCurrentSource) false else state.previewIsLoading,
        )
        mutableState.value = refreshedState
        if (refreshedState.emptyPlaybackCompleted) {
            // 双路搜索完成仍无可播源时，真实 Playing 事件不会到达，立即走推荐兜底。
            scheduleRecommends(
                serial = loadSerial,
                delayMs = 0L,
                trigger = "empty-playback",
            )
        }
    }

    /**
     * 启动或刷新预览播放器状态。
     */
    private fun startPreviewPlayback() {
        val request = mutableState.value.playbackRequest ?: return
        val serial = loadSerial
        val engine = playerEngine
        if (engine == null) {
            // 已生成有效请求但没有播放器内核时，页面无法收到 Playing 状态，立即加载推荐。
            scheduleRecommends(
                serial = serial,
                delayMs = 0L,
                trigger = "missing-player-engine",
            )
            return
        }
        previewPlayerJob?.cancel()
        previewPlayerJob = CoroutineScope(previewDispatcher).launch {
            if (engine.state.value.matchesPlaybackRequest(request)) {
                // 详情页重新接管共享会话时，如果底层仍是同一媒体，只同步状态，不重新 load。
                applyPreviewPlayerState(
                    playerState = engine.state.value,
                    expectedRequest = request,
                    serial = serial,
                )
            } else {
                mutableState.value = mutableState.value.copy(previewIsLoading = true)
                try {
                    engine.load(request)
                } catch (cancellation: CancellationException) {
                    // 切源、切集和页面释放产生的协程取消不是播放器业务失败。
                    throw cancellation
                } catch (_: Throwable) {
                    // 真实预览起播失败时必须结束 loading，避免头图区域无限转圈。
                    mutableState.value = mutableState.value.copy(
                        previewIsLoading = false,
                        previewIsPlaying = false,
                    )
                    scheduleRecommends(
                        serial = serial,
                        delayMs = 0L,
                        trigger = "player-load-failure",
                    )
                    return@launch
                }
            }
            engine.state.collect { playerState ->
                applyPreviewPlayerState(
                    playerState = playerState,
                    expectedRequest = request,
                    serial = serial,
                )
            }
        }
    }

    /**
     * 将播放器内核状态同步到详情页预览状态。
     *
     * @param playerState 当前播放器状态。
     * @param expectedRequest 当前监听任务对应的播放请求。
     * @param serial 当前详情加载序号。
     */
    private fun applyPreviewPlayerState(
        playerState: PlayerState,
        expectedRequest: PlaybackRequest,
        serial: Long,
    ) {
        if (!isActiveSerial(serial)) {
            return
        }
        val state = mutableState.value
        if (state.playbackRequest?.toPlaybackIdentity() != expectedRequest.toPlaybackIdentity()) {
            // 当前页面已经切到其它线路或剧集时，旧监听任务的任何状态都不能回写预览区。
            return
        }
        when (playerState) {
            is PlayerState.Playing -> {
                if (!playerState.matchesPlaybackRequest(expectedRequest)) {
                    // 共享播放器正在播放其它媒体时，不能污染当前详情的播放状态和续播位置。
                    return
                }
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
                maybeSavePreviewProgress(
                    request = expectedRequest,
                    positionMs = snapshot.positionMs,
                    durationMs = snapshot.durationMs,
                )
                // 只有当前媒体真实进入 Playing 后，才按 Flutter TV 契约延迟加载推荐。
                scheduleRecommends(
                    serial = serial,
                    delayMs = RECOMMEND_PLAYING_DELAY_MS,
                    trigger = "preview-playing",
                )
            }

            is PlayerState.Paused -> {
                val snapshot = playerState.snapshot
                if (snapshot != null && !playerState.matchesPlaybackRequest(expectedRequest)) {
                    // 共享会话的其它媒体暂停状态不能覆盖当前详情预览状态。
                    return
                }
                mutableState.value = state.copy(
                    previewPlayerReady = snapshot != null || state.previewPlayerReady,
                    previewIsLoading = false,
                    previewIsPlaying = false,
                    previewPositionMs = snapshot?.positionMs ?: state.previewPositionMs,
                    previewDurationMs = snapshot?.durationMs ?: state.previewDurationMs,
                )
                if (snapshot != null) {
                    maybeSavePreviewProgress(
                        request = expectedRequest,
                        positionMs = snapshot.positionMs,
                        durationMs = snapshot.durationMs,
                    )
                }
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
                // 当前媒体明确进入错误终态后，延迟 Playing 触发不再可能，立即加载推荐。
                scheduleRecommends(
                    serial = serial,
                    delayMs = 0L,
                    trigger = "player-error",
                )
            }

            is PlayerState.Idle -> Unit
        }
    }

    /**
     * 按 10 秒分段保存详情页预览进度。
     *
     * 进入新媒体时只记录当前分段基线，不立即重复保存；
     * 同一媒体回退到更早位置时立即覆盖，保证续播时间点跟随真实当前位置。
     *
     * @param request 当前播放请求。
     * @param positionMs 当前播放位置，单位毫秒。
     * @param durationMs 当前总时长，单位毫秒。
     */
    private fun maybeSavePreviewProgress(
        request: PlaybackRequest,
        positionMs: Long,
        durationMs: Long,
    ) {
        val identity = request.toPlaybackIdentity()
        val currentBucket = (positionMs.coerceAtLeast(0L) / PROGRESS_SAVE_INTERVAL_MS)
        if (lastPreviewSavedIdentity != identity) {
            lastPreviewSavedIdentity = identity
            lastPreviewSavedBucket = currentBucket
            return
        }
        if (currentBucket < lastPreviewSavedBucket) {
            savePlaybackProgress(request, positionMs, durationMs)
            lastPreviewSavedBucket = currentBucket
            return
        }
        if (currentBucket <= lastPreviewSavedBucket || currentBucket <= 0L) {
            return
        }
        savePlaybackProgress(request, positionMs, durationMs)
        lastPreviewSavedBucket = currentBucket
    }

    /**
     * 安排当前详情的唯一推荐任务。
     *
     * @param serial 当前详情加载序号。
     * @param delayMs 请求前等待毫秒数。
     * @param trigger 推荐调度触发原因。
     */
    private fun scheduleRecommends(
        serial: Long,
        delayMs: Long,
        trigger: String,
    ) {
        val entry = currentEntry ?: return
        if (!isActiveSerial(serial) || recommendStartedSerial == serial) {
            return
        }
        recommendStartedSerial = serial
        mutableState.value = mutableState.value.copy(
            recommendLoadState = TvDetailRecommendLoadState.Scheduled,
            recommendErrorMessage = null,
        )
        recordRecommendDiagnostic(
            stage = TvDetailRecommendDiagnosticStage.Scheduled,
            entry = entry,
            trigger = trigger,
        )
        recommendJob = getOrCreateBackgroundScope().launch(start = CoroutineStart.UNDISPATCHED) {
            if (delayMs > 0L) {
                delay(delayMs)
            }
            if (!isActiveSerial(serial)) {
                recordRecommendDiagnostic(
                    stage = TvDetailRecommendDiagnosticStage.StaleIgnored,
                    entry = entry,
                    trigger = trigger,
                )
                return@launch
            }
            mutableState.value = mutableState.value.copy(
                recommendLoadState = TvDetailRecommendLoadState.Loading,
                recommendErrorMessage = null,
            )
            recordRecommendDiagnostic(
                stage = TvDetailRecommendDiagnosticStage.Loading,
                entry = entry,
                trigger = trigger,
            )
            try {
                val cards = loadRecommends(entry, mutableState.value.detail)
                applyRecommendSuccess(
                    serial = serial,
                    entry = entry,
                    cards = cards,
                    trigger = trigger,
                )
            } catch (throwable: Throwable) {
                if (throwable is CancellationException) {
                    // 页面释放或新详情接管产生的取消不属于业务失败。
                    throw throwable
                }
                applyRecommendFailure(
                    serial = serial,
                    entry = entry,
                    throwable = throwable,
                    trigger = trigger,
                )
            }
        }
    }

    /**
     * 应用推荐成功结果。
     *
     * @param serial 结果所属详情加载序号。
     * @param entry 结果所属详情入口。
     * @param cards 推荐卡片列表。
     * @param trigger 推荐调度触发原因。
     */
    private fun applyRecommendSuccess(
        serial: Long,
        entry: TvDetailEntry,
        cards: List<TvVideoCard>,
        trigger: String,
    ) {
        if (!isActiveSerial(serial)) {
            recordRecommendDiagnostic(
                stage = TvDetailRecommendDiagnosticStage.StaleIgnored,
                entry = entry,
                trigger = trigger,
                count = cards.size,
            )
            return
        }
        val loadState = if (cards.isEmpty()) {
            TvDetailRecommendLoadState.Empty
        } else {
            TvDetailRecommendLoadState.Loaded
        }
        mutableState.value = mutableState.value.copy(
            recommendCards = cards,
            recommendLoadState = loadState,
            recommendErrorMessage = null,
        )
        recordRecommendDiagnostic(
            stage = if (cards.isEmpty()) {
                TvDetailRecommendDiagnosticStage.Empty
            } else {
                TvDetailRecommendDiagnosticStage.Success
            },
            entry = entry,
            trigger = trigger,
            count = cards.size,
        )
    }

    /**
     * 应用推荐失败结果。
     *
     * @param serial 结果所属详情加载序号。
     * @param entry 结果所属详情入口。
     * @param throwable 推荐加载异常。
     * @param trigger 推荐调度触发原因。
     */
    private fun applyRecommendFailure(
        serial: Long,
        entry: TvDetailEntry,
        throwable: Throwable,
        trigger: String,
    ) {
        val diagnosticMessage = buildRecommendFailureMessage(throwable)
        if (!isActiveSerial(serial)) {
            recordRecommendDiagnostic(
                stage = TvDetailRecommendDiagnosticStage.StaleIgnored,
                entry = entry,
                trigger = trigger,
                message = diagnosticMessage,
            )
            return
        }
        mutableState.value = mutableState.value.copy(
            recommendLoadState = TvDetailRecommendLoadState.Failed,
            recommendErrorMessage = throwable.message
                ?.trim()
                ?.takeIf { message -> message.isNotEmpty() }
                ?: "相关推荐加载失败",
        )
        recordRecommendDiagnostic(
            stage = TvDetailRecommendDiagnosticStage.Failure,
            entry = entry,
            trigger = trigger,
            message = diagnosticMessage,
        )
    }

    /**
     * 构造不包含响应正文或鉴权信息的失败诊断。
     *
     * @param throwable 推荐加载异常。
     * @return 异常类型和简短消息。
     */
    private fun buildRecommendFailureMessage(throwable: Throwable): String {
        val typeName = throwable::class.simpleName.orEmpty().ifBlank { "Throwable" }
        val rawMessage = throwable.message.orEmpty().trim().ifBlank { "无错误说明" }
        val message = if (RECOMMEND_DIAGNOSTIC_SENSITIVE_MARKERS.any { marker ->
                rawMessage.contains(marker, ignoreCase = true)
            }
        ) {
            // HTML 正文和常见鉴权字段不能进入结构化诊断事件。
            "已省略敏感错误内容"
        } else {
            rawMessage.replace(Regex("""\s+"""), " ")
                .take(MAX_RECOMMEND_DIAGNOSTIC_MESSAGE_LENGTH)
        }
        return "$typeName: $message"
    }

    /**
     * 记录推荐诊断，诊断失败不能反向影响详情业务。
     *
     * @param stage 推荐诊断阶段。
     * @param entry 详情入口。
     * @param trigger 推荐调度触发原因。
     * @param count 推荐结果数量。
     * @param message 简洁诊断信息。
     */
    private fun recordRecommendDiagnostic(
        stage: TvDetailRecommendDiagnosticStage,
        entry: TvDetailEntry?,
        trigger: String,
        count: Int? = null,
        message: String? = null,
    ) {
        val event = TvDetailRecommendDiagnostic(
            stage = stage,
            entryKey = entry.detailEntryKey(),
            trigger = trigger,
            count = count,
            message = message,
        )
        runCatching { recommendDiagnosticSink.record(event) }
    }

    /**
     * 构造推荐诊断使用的稳定详情标识。
     *
     * @return `source::videoId` 形式的入口标识。
     */
    private fun TvDetailEntry?.detailEntryKey(): String {
        val entry = this ?: return "::"
        return "${entry.source.trim()}::${entry.videoId.trim()}"
    }

    /**
     * 获取或创建详情页后台任务作用域。
     *
     * @return 详情加载和推荐任务共享的后台作用域。
     */
    private fun getOrCreateBackgroundScope(): CoroutineScope {
        return backgroundScope ?: CoroutineScope(SupervisorJob() + previewDispatcher).also { createdScope ->
            backgroundScope = createdScope
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
     * 判断当前是否需要再次发起详情加载。
     *
     * @param videoId 当前详情页视频 ID。
     * @return 仍需发起加载时返回 true。
     */
    private fun shouldStartLoad(videoId: String): Boolean {
        val normalizedVideoId = videoId.trim()
        if (normalizedVideoId.isBlank()) {
            return false
        }
        val currentLoadingVideoId = activeLoadVideoId.orEmpty()
        if (currentLoadingVideoId == normalizedVideoId && detailLoadJob?.isActive == true) {
            // 页面切到全屏后立即返回时，仍在执行的同视频加载任务必须继续复用。
            return false
        }
        val currentVideoId = currentEntry?.videoId.orEmpty()
        val isSameEntry = currentVideoId == normalizedVideoId
        if (!isSameEntry) {
            return true
        }
        val state = mutableState.value
        return state.detail == null ||
            (!state.initialSourcesLoaded && !state.moreSourcesLoaded && state.currentSourceId.isBlank())
    }

    /**
     * 释放详情页内部持有的后台任务。
     */
    fun release() {
        detailLoadJob?.cancel()
        previewPlayerJob?.cancel()
        recommendJob?.cancel()
        activeLoadVideoId = null
        recommendStartedSerial = null
        lastPreviewSavedIdentity = null
        lastPreviewSavedBucket = UNINITIALIZED_PROGRESS_BUCKET
        backgroundScope?.cancel()
        backgroundScope = null
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
        (currentSources + incomingSources).toPlayableSources().forEach { source ->
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
        return playableEpisodes().getOrNull(resumeIndex)?.id ?: firstPlayableEpisodeIdOrEmpty()
    }

    /**
     * 刷新当前剧集 ID。
     *
     * @param currentEpisodeId 当前剧集 ID。
     * @return 新线路仍可用的剧集 ID。
     */
    private fun TvVideoSource?.resolveRefreshedEpisodeId(currentEpisodeId: String): String {
        if (this == null) return currentEpisodeId
        return playableEpisodes().firstOrNull { episode -> episode.id == currentEpisodeId }?.id
            ?: firstPlayableEpisodeIdOrEmpty()
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
     * 获取线路中的可播放剧集。
     *
     * @return 已过滤空地址后的剧集列表。
     */
    private fun TvVideoSource.playableEpisodes(): List<TvEpisode> {
        return episodes.filter { episode -> episode.hasPlayableUrl() }
    }

    /**
     * 判断线路是否仍然存在真实可播放剧集。
     *
     * @return 至少一集有真实地址时返回 true。
     */
    private fun TvVideoSource.hasPlayableEpisodes(): Boolean {
        return playableEpisodes().isNotEmpty()
    }

    /**
     * 获取线路首个可播放剧集 ID。
     *
     * @return 首个可播放剧集 ID。
     */
    private fun TvVideoSource.firstPlayableEpisodeIdOrEmpty(): String {
        return playableEpisodes().firstOrNull()?.id.orEmpty()
    }

    /**
     * 判断当前剧集是否具备真实播放地址。
     *
     * @return 地址非空时返回 true。
     */
    private fun TvEpisode.hasPlayableUrl(): Boolean {
        return url.trim().isNotBlank()
    }

    /**
     * 把线路列表收口为仅包含可播放剧集的版本。
     *
     * @return 已过滤空地址剧集与空线路的列表。
     */
    private fun List<TvVideoSource>.toPlayableSources(): List<TvVideoSource> {
        return map { source ->
            source.copy(episodes = source.playableEpisodes())
        }.filter { source ->
            source.episodes.isNotEmpty()
        }
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

    /**
     * 合并详情元数据（简介/年份/封面/豆瓣 ID）。
     *
     * 仅回填当前仍为空的字段，避免增量搜索把已有精确详情覆盖成空。
     *
     * @param incoming 接口或搜索返回的详情元数据。
     */
    private fun mergeDetailMetadata(incoming: TvVideoDetail?) {
        if (incoming == null) {
            return
        }
        val state = mutableState.value
        val current = state.detail ?: currentEntry.toBaseDetail(emptyList()) ?: return
        val merged = current.copy(
            // 简介：接口/搜索有 desc 时覆盖入口占位空串。
            description = current.description.ifBlank { incoming.description },
            title = current.title.ifBlank { incoming.title },
            posterUrl = current.posterUrl.ifBlank { incoming.posterUrl },
            year = current.year.ifBlank { incoming.year },
            typeName = current.typeName.ifBlank { incoming.typeName },
            // 分类以更完整一侧为准，避免后到空列表覆盖已解析标签。
            categories = if (current.categories.size >= incoming.categories.size) {
                current.categories.ifEmpty { incoming.categories }
            } else {
                incoming.categories
            },
            remarks = current.remarks.ifBlank { incoming.remarks },
            qualityTag = current.qualityTag.ifBlank { incoming.qualityTag },
            rating = current.rating.ifBlank { incoming.rating },
            doubanId = current.doubanId.ifBlank { incoming.doubanId },
            sourceName = current.sourceName.ifBlank { incoming.sourceName },
            // 线路列表仍由 mergeSources 统一处理，这里只合并资料字段。
            sources = current.sources.ifEmpty { incoming.sources },
        )
        if (merged != current) {
            mutableState.value = state.copy(detail = merged)
        }
    }

    private companion object {
        /** 选集分组大小。 */
        const val EPISODE_GROUP_SIZE = 20

        /** 真实预览开始后等待推荐加载的毫秒数。 */
        const val RECOMMEND_PLAYING_DELAY_MS = 2_000L

        /** 详情页预览续播进度保存间隔。 */
        const val PROGRESS_SAVE_INTERVAL_MS = 10_000L

        /** 预览进度尚未初始化的分段值。 */
        const val UNINITIALIZED_PROGRESS_BUCKET = -1L

        /** 推荐失败诊断允许保留的最大消息长度。 */
        const val MAX_RECOMMEND_DIAGNOSTIC_MESSAGE_LENGTH = 160

        /** 推荐失败诊断需要过滤的 HTML 与鉴权标记。 */
        val RECOMMEND_DIAGNOSTIC_SENSITIVE_MARKERS = listOf(
            "<html",
            "cookie",
            "authorization",
            "password",
            "token",
        )
    }
}
