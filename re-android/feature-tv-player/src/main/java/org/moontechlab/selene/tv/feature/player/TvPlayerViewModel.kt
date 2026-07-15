package org.moontechlab.selene.tv.feature.player

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.player.api.PlaybackEpisode
import org.moontechlab.selene.tv.core.player.api.PlaybackIdentity
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSource
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState
import org.moontechlab.selene.tv.core.player.api.TvResizeMode
import org.moontechlab.selene.tv.core.player.api.matchesPlaybackRequest
import org.moontechlab.selene.tv.core.player.api.snapshotOrNull
import org.moontechlab.selene.tv.core.player.api.toPlaybackIdentity

/**
 * TV 全屏播放器界面状态。
 *
 * @property playbackRequest 当前详情页传入的播放请求。
 * @property isPlayerLoading 是否正在向播放器内核加载请求。
 * @property isPlaybackPlaying 当前播放器是否正在播放。
 * @property currentPositionMs 当前播放位置，单位毫秒。
 * @property durationMs 当前总时长，单位毫秒。
 * @property cachedRanges 当前播放器已缓存范围，单位毫秒。
 * @property networkSpeedBytesPerSecond 当前播放器下载网速，单位 B/s。
 * @property playerErrorMessage 播放器加载错误文案。
 * @property isSeekGestureActive 左右键是否仍按住（按住期间不展示加载转圈）。
 * @property isPostSeekLoading 松手后等待起播的加载动画，直到 Playing/Paused 就绪后清除。
 * @property isSeekOverlayVisible 中心 seek 提示是否可见。
 * @property seekOverlayDirection 当前 seek 方向，`1` 为快进，`-1` 为快退。
 * @property seekOverlayPositionMs 实际下发给播放器的 seek 目标位置。
 * @property seekOverlayDisplayPositionMs 中心提示展示位置，后续长按可与真实目标分离。
 * @property seekOverlayDurationMs 中心提示展示总时长。
 * @property isMenuVisible 底部菜单是否可见。
 * @property selectedTopMenu 当前一级菜单。
 * @property selectedPlaybackSpeed 当前倍速菜单选中值。
 * @property selectedResizeMode 当前画面比例菜单选中值。
 * @property skipIntroSeconds 片头跳过秒数。
 * @property skipOutroSeconds 片尾跳过剩余秒数。
 * @property isDanmakuEnabled 当前弹幕开关是否启用。
 * @property isDanmakuLoading 是否正在加载当前剧集弹幕。
 * @property currentDanmakuEpisodeId 当前命中的弹幕剧集 ID。
 * @property danmakuComments 当前剧集弹幕评论。
 * @property danmakuEmissionVersion 弹幕发射批次版本，用于 UI 识别新一轮渲染。
 * @property danmakuEmissionComments 当前进度新发射的弹幕评论。
 * @property danmakuErrorMessage 弹幕加载错误文案。
 * @property switchLoadingMessage 中心加载层自定义文案；空则显示默认「加载中」。
 * @property actionNoticeText 底部动作提示（如自动下一集），空表示不展示。
 */
data class TvPlayerUiState(
    val playbackRequest: PlaybackRequest? = null,
    val isPlayerLoading: Boolean = false,
    val isPlaybackPlaying: Boolean = false,
    val currentPositionMs: Long = playbackRequest?.startPositionMs ?: 0L,
    val durationMs: Long = 0L,
    val cachedRanges: List<TvPlayerCachedRange> = emptyList(),
    val networkSpeedBytesPerSecond: Long = 0L,
    val playerErrorMessage: String? = null,
    val isSeekGestureActive: Boolean = false,
    val isPostSeekLoading: Boolean = false,
    val isSeekOverlayVisible: Boolean = false,
    val seekOverlayDirection: Int = 0,
    val seekOverlayPositionMs: Long = currentPositionMs,
    val seekOverlayDisplayPositionMs: Long = seekOverlayPositionMs,
    val seekOverlayDurationMs: Long = durationMs,
    val isMenuVisible: Boolean = false,
    val selectedTopMenu: String = PLAYER_MENU_PLAYLIST,
    val selectedPlaybackSpeed: Float = playbackRequest?.playbackSpeed ?: PLAYER_DEFAULT_SPEED,
    val selectedResizeMode: TvResizeMode = playbackRequest?.resizeMode ?: TvResizeMode.FIT,
    val skipIntroSeconds: Int = 0,
    val skipOutroSeconds: Int = 0,
    val isDanmakuEnabled: Boolean = true,
    val isDanmakuLoading: Boolean = false,
    val currentDanmakuEpisodeId: Int? = null,
    val danmakuComments: List<TvPlayerDanmakuComment> = emptyList(),
    val danmakuEmissionVersion: Int = 0,
    val danmakuEmissionComments: List<TvPlayerDanmakuComment> = emptyList(),
    val danmakuErrorMessage: String? = null,
    // 线路 & 选集
    val availableSources: List<PlaybackSource> = emptyList(),
    val allEpisodes: List<PlaybackEpisode> = emptyList(),
    val selectedEpisodeGroup: Int = 0,
    val switchLoadingMessage: String? = null,
    val actionNoticeText: String? = null,
)

/**
 * TV 播放器缓存区间。
 *
 * @property startMs 缓存起点，单位毫秒。
 * @property endMs 缓存终点，单位毫秒。
 */
data class TvPlayerCachedRange(
    val startMs: Long,
    val endMs: Long,
)

/**
 * 底部进度条可绘制缓存分段。
 *
 * @property startFraction 分段起点比例，范围 0..1。
 * @property endFraction 分段终点比例，范围 0..1。
 */
data class TvPlayerCachedProgressSegment(
    val startFraction: Float,
    val endFraction: Float,
)

/**
 * 播放器弹幕加载结果。
 *
 * @property episodeId 命中的弹幕剧集 ID。
 * @property comments 当前剧集弹幕评论。
 */
data class TvPlayerDanmakuLoadResult(
    val episodeId: Int,
    val comments: List<TvPlayerDanmakuComment>,
)

/**
 * 播放器弹幕评论模型。
 *
 * @property cid 评论 ID。
 * @property p 原始弹幕参数。
 * @property text 弹幕正文。
 * @property timestamp 服务端时间戳。
 * @property timeSeconds 弹幕出现时间，单位秒。
 * @property type 弹幕类型，1 为滚动，4 为底部，5 为顶部。
 * @property color 弹幕颜色。
 */
data class TvPlayerDanmakuComment(
    val cid: Int,
    val p: String,
    val text: String,
    val timestamp: Int,
    val timeSeconds: Double,
    val type: Int,
    val color: Int,
)

/**
 * TV 全屏播放器 ViewModel。
 *
 * @param initialRequest 从详情页进入播放器时携带的播放请求。
 * @param playerEngine 当前播放器内核。
 * @param loadDanmaku 当前播放请求对应的弹幕加载器。
 * @param loadSkipIntroSeconds 片头跳过秒数读取器。
 * @param loadSkipOutroSeconds 片尾跳过秒数读取器。
 * @param saveSkipIntroSeconds 片头跳过秒数保存器。
 * @param saveSkipOutroSeconds 片尾跳过秒数保存器。
 * @param savePlaybackProgress 全屏播放进度保存器。
 */
class TvPlayerViewModel(
    initialRequest: PlaybackRequest? = null,
    private val playerEngine: PlayerEngine? = null,
    private val seekController: TvSeekController = TvSeekController(),
    private val availableSources: List<PlaybackSource> = emptyList(),
    private val allEpisodes: List<PlaybackEpisode> = emptyList(),
    private val loadDanmaku: suspend (PlaybackRequest) -> TvPlayerDanmakuLoadResult? = { null },
    private val loadSkipIntroSeconds: suspend () -> Int = { 0 },
    private val loadSkipOutroSeconds: suspend () -> Int = { 0 },
    private val saveSkipIntroSeconds: suspend (Int) -> Unit = {},
    private val saveSkipOutroSeconds: suspend (Int) -> Unit = {},
    private val savePlaybackProgress: (PlaybackRequest, Long, Long) -> Unit = { _, _, _ -> },
    /** 松手转圈最短可见毫秒；单测可置 0 避免依赖真实时钟/Main delay。 */
    private val postSeekMinVisibleMs: Long = POST_SEEK_LOADING_MIN_VISIBLE_MS,
    /** 单调时钟毫秒；默认 currentTimeMillis，避免单测 mock SystemClock。 */
    private val elapsedRealtimeMs: () -> Long = { System.currentTimeMillis() },
) {
    /** 播放器内部状态。 */
    private val mutableState = MutableStateFlow(
        TvPlayerUiState(
            playbackRequest = initialRequest,
            availableSources = availableSources,
            allEpisodes = allEpisodes,
        ),
    )

    /** 播放器公开状态。 */
    val state: StateFlow<TvPlayerUiState> = mutableState

    /** 本轮方向键按压开始时的中心提示展示基准位置。 */
    private var seekOverlayDisplayBasePositionMs: Long? = null

    /** 当前弹幕时间轴待发射的游标下标。 */
    private var danmakuCursorIndex: Int = 0

    /** 上一次检查弹幕发射的播放时间，单位秒。 */
    private var lastDanmakuCheckTimeSeconds: Double = DANMAKU_UNCHECKED_TIME_SECONDS

    /** 当前全屏媒体最近一次已保存的续播分段。 */
    private var lastSavedProgressBucket: Long = UNINITIALIZED_PROGRESS_BUCKET

    /** 当前全屏媒体最近一次保存对应的媒体身份。 */
    private var lastSavedProgressIdentity: PlaybackIdentity? = null

    /** 松手后加载动画会话（用于最短展示与取消旧任务）。 */
    private var postSeekSessionId: Int = 0

    /** 松手时刻（elapsedRealtime），保证转圈至少可见一小段。 */
    private var postSeekReleasedAtElapsedMs: Long = 0L

    /** 松手后最短展示/收口任务。 */
    private var postSeekLoadingJob: Job? = null

    /**
     * 已对某集触发过自动下一集的媒体身份。
     *
     * 同一集只触发一次，避免 ended / 片尾跳过 / 进度轮询重复切集。
     */
    private var autoNextConsumedIdentity: PlaybackIdentity? = null

    /** 自动下一集是否正在执行，防止 collect 与 tick 并发重入。 */
    private var autoNextInFlight: Boolean = false

    /** ViewModel 内部协程（松手转圈收口用；Default 避免单测无 Main 崩溃）。 */
    private val viewModelScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    /**
     * 将详情页传入的播放请求下发给播放器内核。
     */
    suspend fun loadInitialRequest() {
        val request = mutableState.value.playbackRequest ?: return
        val engine = playerEngine ?: return
        if (engine.state.value.matchesPlaybackRequest(request)) {
            // 详情页预览切全屏时，如果共享会话已经在同一媒体上，直接接管状态，避免再次重载。
            mutableState.value = mutableState.value.copy(
                isPlayerLoading = false,
                playerErrorMessage = null,
            )
            syncPlayerState(engine.state.value)
            return
        }
        mutableState.value = mutableState.value.copy(
            isPlayerLoading = true,
            playerErrorMessage = null,
        )
        runCatching {
            engine.load(request)
        }.onSuccess {
            syncPlayerState(engine.state.value)
        }.onFailure { throwable ->
            // 播放器加载失败只影响播放画面，不应破坏底部菜单和返回能力。
            mutableState.value = mutableState.value.copy(
                isPlayerLoading = false,
                playerErrorMessage = throwable.message ?: "播放器加载失败",
            )
        }
    }

    /**
     * 全屏菜单切换剧集。
     *
     * 对齐 Flutter TV：切集后从 0 秒起播，并刷新弹幕。
     *
     * @param episodeId 目标剧集 ID。
     * @param switchLoadingMessage 切集时中心加载文案；默认通用「切换选集...」。
     */
    suspend fun selectEpisode(
        episodeId: String,
        switchLoadingMessage: String? = "切换选集...",
    ) {
        val current = mutableState.value.playbackRequest ?: return
        val targetId = episodeId.trim()
        if (targetId.isBlank() || targetId == current.episodeId) {
            return
        }
        val episodes = mutableState.value.allEpisodes
        val index = episodes.indexOfFirst { episode -> episode.id == targetId }
        if (index < 0) {
            return
        }
        val episode = episodes[index]
        val nextRequest = current.copy(
            episodeId = episode.id,
            episodeIndex = index,
            episodeTitle = episode.title,
            // 有地址时直接切集；空地址时仍保留当前 url，避免误下发空白媒体。
            url = episode.url.trim().ifBlank { current.url },
            startPositionMs = 0L,
        )
        mutableState.value = mutableState.value.copy(
            playbackRequest = nextRequest,
            isMenuVisible = false,
            isSeekOverlayVisible = false,
            isPlayerLoading = true,
            switchLoadingMessage = switchLoadingMessage,
            playerErrorMessage = null,
            currentPositionMs = 0L,
            durationMs = 0L,
        )
        val engine = playerEngine
        if (engine == null) {
            mutableState.value = mutableState.value.copy(
                isPlayerLoading = false,
                switchLoadingMessage = null,
            )
            return
        }
        runCatching {
            engine.load(nextRequest)
        }.onSuccess {
            syncPlayerState(engine.state.value)
            loadDanmakuForCurrentRequest()
        }.onFailure { throwable ->
            mutableState.value = mutableState.value.copy(
                isPlayerLoading = false,
                switchLoadingMessage = null,
                playerErrorMessage = throwable.message ?: "切换剧集失败",
            )
        }
    }

    /**
     * 关闭底部动作提示（自动下一集等）。
     */
    fun dismissActionNotice() {
        if (mutableState.value.actionNoticeText == null) {
            return
        }
        mutableState.value = mutableState.value.copy(actionNoticeText = null)
    }

    /**
     * 全屏菜单切换线路。
     *
     * 当前上下文若只提供线路摘要，则先更新选中线路；
     * 若详情已同步同一 source 的剧集列表，则继续用首集地址起播。
     *
     * @param sourceId 目标线路 ID。
     */
    suspend fun selectSource(sourceId: String) {
        val current = mutableState.value.playbackRequest ?: return
        val targetId = sourceId.trim()
        if (targetId.isBlank() || targetId == current.sourceId) {
            return
        }
        val source = mutableState.value.availableSources.firstOrNull { item -> item.id == targetId }
            ?: return
        val nextRequest = current.copy(
            sourceId = source.id,
            // 切线路后默认从当前集/首集继续；没有新地址时保留旧 url，等待详情同步。
            startPositionMs = 0L,
        )
        mutableState.value = mutableState.value.copy(
            playbackRequest = nextRequest,
            isMenuVisible = false,
            isSeekOverlayVisible = false,
            isPlayerLoading = true,
            playerErrorMessage = null,
            currentPositionMs = 0L,
        )
        val engine = playerEngine
        if (engine == null) {
            mutableState.value = mutableState.value.copy(isPlayerLoading = false)
            return
        }
        runCatching {
            engine.load(nextRequest)
        }.onSuccess {
            syncPlayerState(engine.state.value)
            loadDanmakuForCurrentRequest()
        }.onFailure { throwable ->
            mutableState.value = mutableState.value.copy(
                isPlayerLoading = false,
                playerErrorMessage = throwable.message ?: "切换线路失败",
            )
        }
    }

    /**
     * 持续观察播放器内核状态。
     */
    suspend fun observePlayerState() {
        val engine = playerEngine ?: return
        coroutineScope {
            // 进度轮询放在 Default，避免和测试调度器绑死；UI 同步仍走 collect 主路径。
            val progressJob = CoroutineScope(Dispatchers.Default).launch {
                while (isActive) {
                    delay(POSITION_TICK_INTERVAL_MS)
                    val playerState = engine.state.value
                    if (playerState !is PlayerState.Playing) {
                        continue
                    }
                    val snapshot = runCatching { engine.captureSnapshot() }.getOrNull() ?: continue
                    val playingState = PlayerState.Playing(snapshot)
                    syncPlayerState(playingState)
                    // 片尾跳过依赖进度 tick，不依赖 ended 事件。
                    maybeAutoPlayNextEpisode(playingState)
                }
            }
            try {
                engine.state.collect { playerState ->
                    // WebView/Exo 的真实进度、暂停和错误都以播放器内核状态为准。
                    syncPlayerState(playerState)
                    // 本集自然结束（Exo STATE_ENDED → Paused 且进度到末尾）时切下一集。
                    maybeAutoPlayNextEpisode(playerState)
                }
            } finally {
                progressJob.cancel()
            }
        }
    }

    /**
     * 加载当前播放请求对应的弹幕评论。
     */
    suspend fun loadDanmakuForCurrentRequest() {
        val request = mutableState.value.playbackRequest ?: return
        if (!mutableState.value.isDanmakuEnabled) {
            return
        }
        mutableState.value = mutableState.value.copy(
            isDanmakuLoading = true,
            danmakuErrorMessage = null,
        )
        runCatching {
            loadDanmaku(request)
        }.onSuccess { result ->
            if (result == null) {
                // 未匹配到弹幕不是播放器错误，只清空当前弹幕态。
                mutableState.value = mutableState.value.copy(
                    isDanmakuLoading = false,
                    currentDanmakuEpisodeId = null,
                    danmakuComments = emptyList(),
                    danmakuEmissionComments = emptyList(),
                    danmakuErrorMessage = null,
                )
                resetDanmakuCursor(positionMs = mutableState.value.currentPositionMs, clearEmission = true)
            } else {
                mutableState.value = mutableState.value.copy(
                    isDanmakuLoading = false,
                    currentDanmakuEpisodeId = result.episodeId,
                    danmakuComments = result.comments.sortedBy { comment -> comment.timeSeconds },
                    danmakuEmissionComments = emptyList(),
                    danmakuErrorMessage = null,
                )
                resetDanmakuCursor(positionMs = mutableState.value.currentPositionMs, clearEmission = true)
                emitDanmakuByPosition(
                    positionMs = mutableState.value.currentPositionMs,
                    canEmit = mutableState.value.isPlaybackPlaying,
                )
            }
        }.onFailure { throwable ->
            // 弹幕失败不影响视频播放，单独记录诊断文案供菜单或覆盖层展示。
            mutableState.value = mutableState.value.copy(
                isDanmakuLoading = false,
                currentDanmakuEpisodeId = null,
                danmakuComments = emptyList(),
                danmakuEmissionComments = emptyList(),
                danmakuErrorMessage = throwable.message ?: "弹幕加载失败",
            )
            resetDanmakuCursor(positionMs = mutableState.value.currentPositionMs, clearEmission = true)
        }
    }

    /**
     * 加载全局片头片尾跳过配置。
     */
    suspend fun loadSkipDurations() {
        val introSeconds = loadSkipIntroSeconds().coerceAtLeast(0)
        val outroSeconds = loadSkipOutroSeconds().coerceAtLeast(0)
        mutableState.value = mutableState.value.copy(
            skipIntroSeconds = introSeconds,
            skipOutroSeconds = outroSeconds,
        )
    }

    /**
     * 切换播放器弹幕开关。
     */
    suspend fun toggleDanmakuEnabled() {
        val nextEnabled = !mutableState.value.isDanmakuEnabled
        mutableState.value = mutableState.value.copy(isDanmakuEnabled = nextEnabled)
        if (!nextEnabled) {
            // 关闭弹幕后立即清空时间轴与已发射批次，避免菜单显示关但画面继续飘弹幕。
            mutableState.value = mutableState.value.copy(
                isDanmakuLoading = false,
                currentDanmakuEpisodeId = null,
                danmakuComments = emptyList(),
                danmakuEmissionComments = emptyList(),
                danmakuErrorMessage = null,
            )
            resetDanmakuCursor(positionMs = mutableState.value.currentPositionMs, clearEmission = true)
            return
        }
        loadDanmakuForCurrentRequest()
    }

    /**
     * 按 Flutter TV 全屏播放器习惯切换播放和暂停。
     */
    suspend fun togglePlayPause() {
        val engine = playerEngine ?: return
        val playing = engine.state.value is PlayerState.Playing || mutableState.value.isPlaybackPlaying
        runCatching {
            if (playing) {
                engine.pause()
            } else {
                engine.play()
            }
        }.onSuccess {
            syncPlayerState(engine.state.value)
        }.onFailure { throwable ->
            // 控制失败只反馈到播放器画布，不影响遥控器继续返回或打开菜单。
            mutableState.value = mutableState.value.copy(
                isPlayerLoading = false,
                playerErrorMessage = throwable.message ?: "播放控制失败",
            )
        }
    }

    /**
     * 按遥控器左右方向执行进度跳转。
     *
     * @param direction 方向，`1` 为快进，`-1` 为快退。
     * @param holdMs 当前方向键按住时长，单位毫秒。
     */
    suspend fun seekByDirection(
        direction: Int,
        holdMs: Long,
    ) {
        val engine = playerEngine ?: return
        if (direction == 0) {
            return
        }
        val deltaMs = seekController.computeDeltaSeconds(holdMs).toLong() * 1_000L * direction
        val basePositionMs = resolveSeekBasePosition()
        if (holdMs < SEEK_LONG_PRESS_START_MS) {
            // 新一轮短按会刷新展示基准，后续长按 tick 用它生成慢速秒个位。
            seekOverlayDisplayBasePositionMs = basePositionMs
        } else if (seekOverlayDisplayBasePositionMs == null) {
            // 直接进入长按测试或系统首个 repeat 到达时，也要以按压前位置作为展示基准。
            seekOverlayDisplayBasePositionMs = basePositionMs
        }
        val targetPositionMs = resolveSeekTargetPosition(deltaMs)
        runCatching {
            engine.seekTo(targetPositionMs)
        }.onSuccess {
            syncPlayerState(engine.state.value)
            showSeekOverlay(
                direction = direction,
                targetPositionMs = targetPositionMs,
                holdMs = holdMs,
            )
            resetDanmakuCursor(positionMs = targetPositionMs, clearEmission = true)
        }.onFailure { throwable ->
            // seek 失败只反馈到播放器画布，不影响继续操作菜单或返回。
            mutableState.value = mutableState.value.copy(
                isPlayerLoading = false,
                playerErrorMessage = throwable.message ?: "进度跳转失败",
            )
        }
    }

    /**
     * 打开指定一级菜单。
     *
     * @param menu 一级菜单名称。
     */
    fun openMenu(menu: String) {
        // 底部菜单由壳层状态控制，不能触发底层播放器重建。
        seekOverlayDisplayBasePositionMs = null
        mutableState.value = mutableState.value.copy(
            isMenuVisible = true,
            isSeekOverlayVisible = false,
            isSeekGestureActive = false,
            isPostSeekLoading = false,
            selectedTopMenu = menu,
        )
    }

    /**
     * 左右方向键按下：进入 seek 手势，按住期间只展示时间提示，不展示加载转圈。
     */
    fun onSeekGestureStarted() {
        postSeekLoadingJob?.cancel()
        postSeekSessionId += 1
        mutableState.value = mutableState.value.copy(
            isSeekGestureActive = true,
            isPostSeekLoading = false,
        )
    }

    /**
     * 左右方向键松手：收起 seek 提示，展示加载转圈直到画面就绪起播。
     *
     * 注意：松手后**不能**立刻用当前 Playing/Paused 清掉转圈——缓存 seek 时内核常仍是
     * Playing，会导致转圈一闪没有。最短展示 + 缓冲结束后的 Playing/Paused 再收口。
     */
    fun onSeekGestureReleased() {
        postSeekLoadingJob?.cancel()
        postSeekSessionId += 1
        val session = postSeekSessionId
        postSeekReleasedAtElapsedMs = elapsedRealtimeMs()
        seekOverlayDisplayBasePositionMs = null
        mutableState.value = mutableState.value.copy(
            isSeekGestureActive = false,
            isSeekOverlayVisible = false,
            // 短按/长按松手统一进入“等画面”加载动画。
            isPostSeekLoading = true,
        )
        // 最短展示后若已不在缓冲，主动收口；若仍 Loading，等 syncPlayerState 在起播时清。
        val minVisible = postSeekMinVisibleMs.coerceAtLeast(0L)
        if (minVisible == 0L) {
            // 单测 / 关闭最短窗口：下一帧按内核态收口。
            reconcilePostSeekLoading()
        } else {
            postSeekLoadingJob = viewModelScope.launch {
                delay(minVisible)
                if (session != postSeekSessionId) {
                    return@launch
                }
                reconcilePostSeekLoading()
            }
        }
    }

    /**
     * 松手加载动画收口：缓冲中继续转；Playing/Paused 就绪则消失。
     */
    fun reconcilePostSeekLoading() {
        if (!mutableState.value.isPostSeekLoading) {
            return
        }
        val engineState = playerEngine?.state?.value
        val keep = resolveKeepPostSeekLoading(engineState)
        if (!keep) {
            mutableState.value = mutableState.value.copy(isPostSeekLoading = false)
        }
    }

    /**
     * 是否继续展示松手后加载转圈。
     *
     * @param playerState 当前内核状态；null 时按最短展示窗口保留。
     */
    private fun resolveKeepPostSeekLoading(playerState: PlayerState?): Boolean {
        if (!mutableState.value.isPostSeekLoading) {
            return false
        }
        // 仍在缓冲：一直转，直到起播。
        if (playerState is PlayerState.Loading) {
            return true
        }
        val minVisible = postSeekMinVisibleMs.coerceAtLeast(0L)
        val elapsed = elapsedRealtimeMs() - postSeekReleasedAtElapsedMs
        if (minVisible > 0L && elapsed < minVisible) {
            // 最短展示未满：即便已 Playing 也先保住动画。
            return true
        }
        return when (playerState) {
            is PlayerState.Playing,
            is PlayerState.Paused,
            -> false
            is PlayerState.Error,
            PlayerState.Idle,
            null,
            -> false
            PlayerState.Loading -> true
        }
    }

    /**
     * 关闭底部菜单。
     */
    fun closeMenu() {
        // 返回键只收起菜单，不重置当前选项，方便再次打开时回到用户刚操作的位置。
        mutableState.value = mutableState.value.copy(isMenuVisible = false)
    }

    /**
     * 选择播放倍速。
     *
     * @param speed Flutter TV 倍速菜单传入的目标倍速。
     */
    suspend fun selectPlaybackSpeed(speed: Float) {
        val normalizedSpeed = speed.takeIf { it > 0f } ?: PLAYER_DEFAULT_SPEED
        val engine = playerEngine
        runCatching {
            engine?.setPlaybackSpeed(normalizedSpeed)
        }.onSuccess {
            // 菜单状态和播放请求同步更新，后续切内核或重载仍能保留倍速。
            mutableState.value = mutableState.value.withPlaybackSpeed(normalizedSpeed)
        }.onFailure { throwable ->
            // 倍速设置失败只提示播放器错误，不关闭菜单，方便用户继续操作。
            mutableState.value = mutableState.value.copy(
                playerErrorMessage = throwable.message ?: "倍速设置失败",
            )
        }
    }

    /**
     * 选择画面比例。
     *
     * @param resizeMode 目标画面比例模式。
     */
    suspend fun selectResizeMode(resizeMode: TvResizeMode) {
        val engine = playerEngine
        runCatching {
            engine?.setResizeMode(resizeMode)
        }.onSuccess {
            // 比例状态写回播放请求，保证切内核时能通过快照继续恢复。
            mutableState.value = mutableState.value.withResizeMode(resizeMode)
        }.onFailure { throwable ->
            // 比例设置失败只提示播放器错误，不影响播放、返回或菜单浏览。
            mutableState.value = mutableState.value.copy(
                playerErrorMessage = throwable.message ?: "画面比例设置失败",
            )
        }
    }

    /**
     * 将当前播放位置保存为片头跳过秒数。
     */
    suspend fun setSkipIntroToCurrentPosition() {
        val durationMs = resolveCurrentDurationMs()
        val positionMs = resolveSeekBasePosition()
        val normalizedPositionMs = if (durationMs > 0L) {
            // 已知总时长时按 Flutter TV 逻辑把当前位置限制在视频范围内。
            positionMs.coerceIn(0L, durationMs)
        } else {
            // 未拿到总时长时仍允许保存非负当前位置，避免刚开播时入口不可用。
            positionMs.coerceAtLeast(0L)
        }
        val seconds = normalizedPositionMs.toWholeSeconds()
        mutableState.value = mutableState.value.copy(
            skipIntroSeconds = seconds,
        )
        saveSkipIntroSeconds(seconds)
    }

    /**
     * 清空片头跳过秒数。
     */
    suspend fun clearSkipIntroPosition() {
        mutableState.value = mutableState.value.copy(skipIntroSeconds = 0)
        saveSkipIntroSeconds(0)
    }

    /**
     * 将当前播放位置保存为片尾剩余秒数。
     */
    suspend fun setSkipOutroToCurrentPosition() {
        val durationMs = resolveCurrentDurationMs()
        if (durationMs <= 0L) {
            // Flutter TV 在未知总时长时不保存片尾，避免得到无意义的剩余秒数。
            return
        }
        val positionMs = resolveSeekBasePosition().coerceIn(0L, durationMs)
        val seconds = (durationMs - positionMs).toWholeSeconds()
        mutableState.value = mutableState.value.copy(
            skipOutroSeconds = seconds,
        )
        saveSkipOutroSeconds(seconds)
    }

    /**
     * 清空片尾跳过秒数。
     */
    suspend fun clearSkipOutroPosition() {
        mutableState.value = mutableState.value.copy(skipOutroSeconds = 0)
        saveSkipOutroSeconds(0)
    }

    /**
     * 隐藏中心 seek 提示。
     */
    fun hideSeekOverlay() {
        // 仅隐藏提示，不清空时间，避免动画收尾期间 UI 文字闪回当前播放时间。
        mutableState.value = mutableState.value.copy(isSeekOverlayVisible = false)
    }

    /**
     * 将播放器内核状态同步到界面状态。
     *
     * @param playerState 当前内核状态。
     */
    private fun syncPlayerState(playerState: PlayerState) {
        val snapshot = playerState.snapshotOrNull()
        val positionMs = snapshot?.positionMs ?: mutableState.value.currentPositionMs
        val request = mutableState.value.playbackRequest
        // 松手转圈：缓冲中保留；起播/就绪且最短展示已过再消失（见 resolveKeepPostSeekLoading）。
        val keepPostSeekLoading = resolveKeepPostSeekLoading(playerState)
        // 起播或失败后清掉切集文案，避免加载层一直显示「自动播放下一集」。
        val nextSwitchLoadingMessage = when (playerState) {
            is PlayerState.Playing,
            is PlayerState.Error,
            -> null
            else -> mutableState.value.switchLoadingMessage
        }
        mutableState.value = mutableState.value.copy(
            isPlayerLoading = playerState is PlayerState.Loading,
            isPlaybackPlaying = playerState is PlayerState.Playing,
            isPostSeekLoading = keepPostSeekLoading,
            currentPositionMs = positionMs,
            durationMs = snapshot?.durationMs ?: mutableState.value.durationMs,
            cachedRanges = snapshot?.cachedRanges?.map { range ->
                TvPlayerCachedRange(
                    startMs = range.startMs,
                    endMs = range.endMs,
                )
            } ?: mutableState.value.cachedRanges,
            networkSpeedBytesPerSecond = snapshot?.networkSpeedBytesPerSecond
                ?: mutableState.value.networkSpeedBytesPerSecond,
            selectedPlaybackSpeed = snapshot?.playbackSpeed ?: mutableState.value.selectedPlaybackSpeed,
            selectedResizeMode = snapshot?.resizeMode ?: mutableState.value.selectedResizeMode,
            playerErrorMessage = (playerState as? PlayerState.Error)?.message,
            switchLoadingMessage = nextSwitchLoadingMessage,
        )
        if (snapshot != null && request != null && playerState.matchesPlaybackRequest(request)) {
            // 只有当前快照仍属于目标媒体时，才允许写入续播记录，避免切集交界处误存旧进度。
            maybeSavePlaybackProgress(
                request = request,
                positionMs = snapshot.positionMs,
                durationMs = snapshot.durationMs,
            )
        }
        emitDanmakuByPosition(
            positionMs = positionMs,
            canEmit = playerState is PlayerState.Playing,
        )
    }

    /**
     * 本集播完或进入片尾跳过窗口时，自动切换下一集。
     *
     * 对齐 Flutter TV / 手机端：有下一集才切；最后一集保持结束态。
     *
     * @param playerState 当前内核状态。
     */
    private suspend fun maybeAutoPlayNextEpisode(playerState: PlayerState) {
        if (autoNextInFlight) {
            return
        }
        if (playerState is PlayerState.Loading || playerState is PlayerState.Error || playerState is PlayerState.Idle) {
            return
        }
        val request = mutableState.value.playbackRequest ?: return
        val identity = request.toPlaybackIdentity()
        if (autoNextConsumedIdentity == identity) {
            return
        }
        val snapshot = playerState.snapshotOrNull()
        // 内核若仍在上报上一集 ended 快照，不能拿来给新集做自动切集判定。
        if (snapshot != null && !playerState.matchesPlaybackRequest(request)) {
            return
        }
        val positionMs = snapshot?.positionMs ?: mutableState.value.currentPositionMs
        val durationMs = snapshot?.durationMs ?: mutableState.value.durationMs
        val isPlaying = playerState is PlayerState.Playing
        val nextEpisode = resolveNextPlaybackEpisode(
            episodes = mutableState.value.allEpisodes,
            currentEpisodeId = request.episodeId,
        ) ?: return

        val skipOutroHit = shouldAutoPlayNextOnSkipOutro(
            isPlaying = isPlaying,
            positionMs = positionMs,
            durationMs = durationMs,
            skipOutroSeconds = mutableState.value.skipOutroSeconds,
        )
        val completedHit = shouldAutoPlayNextOnCompleted(
            isPlaying = isPlaying,
            positionMs = positionMs,
            durationMs = durationMs,
        )
        if (!skipOutroHit && !completedHit) {
            return
        }

        autoNextConsumedIdentity = identity
        autoNextInFlight = true
        val reason = if (skipOutroHit) {
            AutoNextReason.SkipOutro
        } else {
            AutoNextReason.Completed
        }
        try {
            performAutoNextEpisode(
                nextEpisode = nextEpisode,
                nextEpisodeIndex = mutableState.value.allEpisodes.indexOfFirst { episode ->
                    episode.id == nextEpisode.id
                },
                reason = reason,
            )
        } finally {
            autoNextInFlight = false
        }
    }

    /**
     * 执行自动下一集：展示提示、加载层文案，并切到目标集。
     *
     * @param nextEpisode 下一集摘要。
     * @param nextEpisodeIndex 下一集绝对下标。
     * @param reason 触发原因。
     */
    private suspend fun performAutoNextEpisode(
        nextEpisode: PlaybackEpisode,
        nextEpisodeIndex: Int,
        reason: AutoNextReason,
    ) {
        val label = nextEpisode.title.ifBlank {
            val displayIndex = (nextEpisodeIndex + 1).coerceAtLeast(1)
            "第${displayIndex.toString().padStart(2, '0')}集"
        }
        val notice = when (reason) {
            AutoNextReason.SkipOutro -> "已跳过片尾，自动播放下一集 · $label"
            AutoNextReason.Completed -> "本集结束，自动播放下一集 · $label"
        }
        mutableState.value = mutableState.value.copy(
            actionNoticeText = notice,
            isMenuVisible = false,
            isSeekOverlayVisible = false,
        )
        selectEpisode(
            episodeId = nextEpisode.id,
            switchLoadingMessage = "自动播放下一集...",
        )
    }

    /**
     * 按 10 秒分段保存全屏播放进度。
     *
     * 进入新媒体时只更新当前分段基线，不立刻重复写库；
     * 同一媒体回退到更早位置时立即覆盖，保证续播时间点跟随真实当前位置。
     *
     * @param request 当前播放请求。
     * @param positionMs 当前播放位置，单位毫秒。
     * @param durationMs 当前总时长，单位毫秒。
     */
    private fun maybeSavePlaybackProgress(
        request: PlaybackRequest,
        positionMs: Long,
        durationMs: Long,
    ) {
        val identity = request.toPlaybackIdentity()
        val currentBucket = (positionMs.coerceAtLeast(0L) / PROGRESS_SAVE_INTERVAL_MS)
        if (lastSavedProgressIdentity != identity) {
            lastSavedProgressIdentity = identity
            lastSavedProgressBucket = currentBucket
            return
        }
        if (currentBucket < lastSavedProgressBucket) {
            savePlaybackProgress(request, positionMs, durationMs)
            lastSavedProgressBucket = currentBucket
            return
        }
        if (currentBucket <= lastSavedProgressBucket || currentBucket <= 0L) {
            return
        }
        savePlaybackProgress(request, positionMs, durationMs)
        lastSavedProgressBucket = currentBucket
    }

    /**
     * 按当前播放位置发射应展示的弹幕批次。
     *
     * @param positionMs 当前播放位置，单位毫秒。
     * @param canEmit 当前是否允许发射弹幕。
     */
    private fun emitDanmakuByPosition(
        positionMs: Long,
        canEmit: Boolean,
    ) {
        val comments = mutableState.value.danmakuComments
        if (
            !canEmit ||
            !mutableState.value.isDanmakuEnabled ||
            comments.isEmpty() ||
            mutableState.value.isDanmakuLoading
        ) {
            return
        }

        val currentSeconds = positionMs / 1_000.0
        if (
            lastDanmakuCheckTimeSeconds != DANMAKU_UNCHECKED_TIME_SECONDS &&
            kotlin.math.abs(currentSeconds - lastDanmakuCheckTimeSeconds) < DANMAKU_MIN_CHECK_INTERVAL_SECONDS
        ) {
            return
        }
        lastDanmakuCheckTimeSeconds = currentSeconds

        val emittedComments = mutableListOf<TvPlayerDanmakuComment>()
        while (danmakuCursorIndex < comments.size) {
            val comment = comments[danmakuCursorIndex]
            if (comment.timeSeconds > currentSeconds) {
                break
            }
            emittedComments += comment
            danmakuCursorIndex += 1
        }

        if (emittedComments.isNotEmpty()) {
            mutableState.value = mutableState.value.copy(
                danmakuEmissionVersion = mutableState.value.danmakuEmissionVersion + 1,
                danmakuEmissionComments = emittedComments,
            )
        }
    }

    /**
     * 重置当前播放位置对应的弹幕游标。
     *
     * @param positionMs 游标定位基准位置，单位毫秒。
     * @param clearEmission 是否清空当前已发射批次。
     */
    private fun resetDanmakuCursor(
        positionMs: Long,
        clearEmission: Boolean,
    ) {
        danmakuCursorIndex = findDanmakuCursorIndex(positionMs)
        lastDanmakuCheckTimeSeconds = DANMAKU_UNCHECKED_TIME_SECONDS
        if (clearEmission) {
            mutableState.value = mutableState.value.copy(danmakuEmissionComments = emptyList())
        }
    }

    /**
     * 二分定位指定播放位置的首条待发射弹幕。
     *
     * @param positionMs 播放位置，单位毫秒。
     * @return 当前时间点之后第一条弹幕下标。
     */
    private fun findDanmakuCursorIndex(positionMs: Long): Int {
        val comments = mutableState.value.danmakuComments
        if (comments.isEmpty()) {
            return 0
        }

        val currentSeconds = positionMs / 1_000.0
        var low = 0
        var high = comments.size
        while (low < high) {
            val mid = low + ((high - low) / 2)
            if (comments[mid].timeSeconds < currentSeconds) {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    /**
     * 根据当前播放快照计算 seek 目标。
     *
     * @param deltaMs 本次跳转偏移，单位毫秒。
     * @return 可下发给播放器内核的目标位置。
     */
    private fun resolveSeekTargetPosition(deltaMs: Long): Long {
        val basePositionMs = resolveSeekBasePosition()
        val rawTargetMs = basePositionMs + deltaMs
        val currentState = playerEngine?.state?.value
        val snapshot = currentState?.snapshotOrNull()
        val durationMs = snapshot?.durationMs ?: mutableState.value.durationMs
        return if (durationMs > 0L) {
            rawTargetMs.coerceIn(0L, durationMs)
        } else {
            rawTargetMs.coerceAtLeast(0L)
        }
    }

    /**
     * 获取当前 seek 计算基准位置。
     *
     * @return 播放器快照或界面状态中的当前播放位置。
     */
    private fun resolveSeekBasePosition(): Long {
        val currentState = playerEngine?.state?.value
        val snapshot = currentState?.snapshotOrNull()
        return snapshot?.positionMs ?: mutableState.value.currentPositionMs
    }

    /**
     * 获取当前播放器总时长。
     *
     * @return 播放器快照或界面状态中的总时长。
     */
    private fun resolveCurrentDurationMs(): Long {
        val currentState = playerEngine?.state?.value
        val snapshot = currentState?.snapshotOrNull()
        return snapshot?.durationMs ?: mutableState.value.durationMs
    }

    /**
     * 显示中心 seek 提示。
     *
     * @param direction seek 方向。
     * @param targetPositionMs 实际下发给播放器的 seek 目标位置。
     * @param holdMs 当前方向键按住时长，单位毫秒。
     */
    private fun showSeekOverlay(
        direction: Int,
        targetPositionMs: Long,
        holdMs: Long,
    ) {
        val safeDirection = if (direction < 0) -1 else 1
        val durationMs = mutableState.value.durationMs
        val displayPositionMs = seekController.computeDisplayPositionMs(
            actualPositionMs = targetPositionMs,
            basePositionMs = seekOverlayDisplayBasePositionMs ?: targetPositionMs,
            holdMs = holdMs,
            direction = safeDirection,
            durationMs = durationMs,
        )
        mutableState.value = mutableState.value.copy(
            isSeekOverlayVisible = true,
            seekOverlayDirection = safeDirection,
            seekOverlayPositionMs = targetPositionMs,
            seekOverlayDisplayPositionMs = displayPositionMs,
            seekOverlayDurationMs = durationMs,
        )
    }
}

/**
 * 是否展示全屏中心加载转圈。
 *
 * 规则：按住快进/快退时不展示；松手后（或首启加载）展示，直到画面就绪。
 */
fun TvPlayerUiState.shouldShowLoadingOverlay(): Boolean {
    if (isSeekGestureActive) {
        return false
    }
    if (isPlayerLoading || isPostSeekLoading) {
        return true
    }
    // 自动下一集/手动切集：起播前保留中心加载层，展示「自动播放下一集...」等文案。
    return !switchLoadingMessage.isNullOrBlank() && !isPlaybackPlaying
}

/**
 * 当前是否还有下一集可自动播放。
 */
fun TvPlayerUiState.hasNextEpisode(): Boolean {
    return resolveNextPlaybackEpisode(
        episodes = allEpisodes,
        currentEpisodeId = playbackRequest?.episodeId.orEmpty(),
    ) != null
}

/**
 * 解析当前集的下一集。
 *
 * @param episodes 全量选集。
 * @param currentEpisodeId 当前剧集 ID。
 * @return 下一集；已是最后一集或不存在时 null。
 */
internal fun resolveNextPlaybackEpisode(
    episodes: List<PlaybackEpisode>,
    currentEpisodeId: String,
): PlaybackEpisode? {
    if (episodes.size < 2) {
        return null
    }
    val currentId = currentEpisodeId.trim()
    if (currentId.isBlank()) {
        return null
    }
    val index = episodes.indexOfFirst { episode -> episode.id == currentId }
    if (index < 0 || index >= episodes.lastIndex) {
        return null
    }
    return episodes[index + 1]
}

/**
 * 判断本集是否已自然播放结束，应自动下一集。
 *
 * Exo `STATE_ENDED` 与 WebView `ended` 都会落到「非 Playing + 进度到末尾」。
 *
 * @param isPlaying 当前是否正在播放。
 * @param positionMs 当前位置。
 * @param durationMs 总时长。
 * @param toleranceMs 末尾容差，吸收内核上报抖动。
 */
internal fun shouldAutoPlayNextOnCompleted(
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
    toleranceMs: Long = PLAYBACK_END_TOLERANCE_MS,
): Boolean {
    if (isPlaying || durationMs <= 0L || positionMs <= 0L) {
        return false
    }
    return positionMs >= (durationMs - toleranceMs).coerceAtLeast(0L)
}

/**
 * 判断是否进入片尾跳过窗口，应自动下一集。
 *
 * 对齐手机端：播放中且剩余秒数 ≤ 片尾跳过设定时切下一集。
 *
 * @param isPlaying 当前是否正在播放。
 * @param positionMs 当前位置。
 * @param durationMs 总时长。
 * @param skipOutroSeconds 片尾跳过剩余秒数设定。
 */
internal fun shouldAutoPlayNextOnSkipOutro(
    isPlaying: Boolean,
    positionMs: Long,
    durationMs: Long,
    skipOutroSeconds: Int,
): Boolean {
    if (!isPlaying || skipOutroSeconds <= 0 || durationMs <= 0L || positionMs <= 0L) {
        return false
    }
    val remainingMs = durationMs - positionMs
    val windowMs = skipOutroSeconds.toLong() * 1_000L
    return remainingMs in 1L..windowMs
}

/**
 * 自动下一集触发原因。
 */
private enum class AutoNextReason {
    /** 本集自然播放到结尾。 */
    Completed,

    /** 进入用户设定的片尾跳过窗口。 */
    SkipOutro,
}

/**
 * 更新 UI 状态中的倍速和播放请求。
 *
 * @param speed 目标播放倍速。
 * @return 已同步倍速的状态。
 */
private fun TvPlayerUiState.withPlaybackSpeed(speed: Float): TvPlayerUiState {
    return copy(
        playbackRequest = playbackRequest?.copy(playbackSpeed = speed),
        selectedPlaybackSpeed = speed,
        playerErrorMessage = null,
    )
}

/**
 * 更新 UI 状态中的画面比例和播放请求。
 *
 * @param resizeMode 目标画面比例。
 * @return 已同步画面比例的状态。
 */
private fun TvPlayerUiState.withResizeMode(resizeMode: TvResizeMode): TvPlayerUiState {
    return copy(
        playbackRequest = playbackRequest?.copy(resizeMode = resizeMode),
        selectedResizeMode = resizeMode,
        playerErrorMessage = null,
    )
}

/**
 * 将毫秒截断为整秒。
 *
 * @return 不超过 Int 上限的非负秒数。
 */
private fun Long.toWholeSeconds(): Int {
    return (this.coerceAtLeast(0L) / 1_000L)
        .coerceAtMost(Int.MAX_VALUE.toLong())
        .toInt()
}

/** 播放列表一级菜单。 */
const val PLAYER_MENU_PLAYLIST = "播放列表"

/** 播放线路一级菜单。 */
const val PLAYER_MENU_SOURCES = "播放线路"

/** 画面比例一级菜单。 */
const val PLAYER_MENU_ASPECT_RATIO = "画面比例"

/** 倍速一级菜单。 */
const val PLAYER_MENU_SPEED = "倍速"

/** 其它一级菜单。 */
const val PLAYER_MENU_OTHER = "其它"

/** Flutter TV 底部一级菜单入口。 */
val PLAYER_PRIMARY_MENU_ITEMS = listOf(
    PLAYER_MENU_PLAYLIST,
    PLAYER_MENU_SOURCES,
    PLAYER_MENU_ASPECT_RATIO,
    PLAYER_MENU_SPEED,
    PLAYER_MENU_OTHER,
)

/** Flutter TV 画面比例二级菜单选项。 */
val PLAYER_ASPECT_RATIO_OPTIONS = listOf("适应", "填充", "宽度", "高度")

/** Flutter TV 倍速二级菜单选项。 */
val PLAYER_SPEED_OPTIONS = listOf("0.75x", "1.0x", "1.25x", "1.5x", "2.0x")

/** 默认倍速选项。 */
const val PLAYER_DEFAULT_SPEED_OPTION = "1.0x"

/** 默认倍速数值。 */
const val PLAYER_DEFAULT_SPEED = 1.0f

/** 片头跳过二级菜单项。 */
const val PLAYER_OTHER_INTRO = "片头 00:00"

/** 片尾跳过二级菜单项。 */
const val PLAYER_OTHER_OUTRO = "片尾 00:00"

/** 弹幕开关二级菜单项。 */
const val PLAYER_OTHER_DANMAKU = "弹幕"

/** 弹幕手动匹配二级菜单项。 */
const val PLAYER_OTHER_MANUAL_MATCH = "手动匹配"

/** Flutter TV 其它菜单实际展示项，禁用清晰度和内核入口。 */
val PLAYER_OTHER_MENU_ITEMS = listOf(
    PLAYER_OTHER_INTRO,
    PLAYER_OTHER_OUTRO,
    PLAYER_OTHER_DANMAKU,
    PLAYER_OTHER_MANUAL_MATCH,
)

/** 长按 seek 起始阈值，用于区分短按展示和长按慢速秒个位展示。 */
private const val SEEK_LONG_PRESS_START_MS = 250L

/**
 * 松手后加载转圈最短可见时长。
 *
 * 缓存 seek 常瞬间仍是 Playing，若立刻收口用户看不到动画。
 */
private const val POST_SEEK_LOADING_MIN_VISIBLE_MS = 350L

/** 全屏播放器续播进度保存间隔。 */
private const val PROGRESS_SAVE_INTERVAL_MS = 10_000L

/** 全屏播放进度主动抓取间隔。 */
private const val POSITION_TICK_INTERVAL_MS = 500L

/**
 * 判定「本集结束」的进度末尾容差。
 *
 * Exo/WebView 上报可能略小于 duration，留 800ms 避免卡在最后一帧不切集。
 */
internal const val PLAYBACK_END_TOLERANCE_MS = 800L

/** 续播进度尚未初始化的分段值。 */
private const val UNINITIALIZED_PROGRESS_BUCKET = -1L

/** Flutter TV 弹幕发射最小检查间隔，避免同一时间点被高频状态流重复推送。 */
private const val DANMAKU_MIN_CHECK_INTERVAL_SECONDS = 0.15

/** 弹幕尚未检查过播放时间的哨兵值。 */
private const val DANMAKU_UNCHECKED_TIME_SECONDS = -1.0
