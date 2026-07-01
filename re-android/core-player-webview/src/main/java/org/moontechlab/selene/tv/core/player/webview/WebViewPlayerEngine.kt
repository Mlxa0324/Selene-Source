package org.moontechlab.selene.tv.core.player.webview

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import org.moontechlab.selene.tv.core.design.threading.DispatcherProvider
import org.moontechlab.selene.tv.core.player.api.PlaybackCachedRange
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSnapshot
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

/**
 * WebView 兜底播放内核。
 *
 * @property dispatchers TV 协程调度器分层。
 */
class WebViewPlayerEngine(
    private val dispatchers: DispatcherProvider,
    private val commandBus: WebViewPlayerCommandBus = WebViewPlayerCommandBus(),
) : PlayerEngine {
    /** WebView 内部状态。 */
    private val mutableState = MutableStateFlow<PlayerState>(PlayerState.Idle)

    /** 最近一次播放快照。 */
    private var lastSnapshot: PlaybackSnapshot? = null

    /** 当前播放器状态。 */
    override val state: StateFlow<PlayerState> = mutableState

    /**
     * 加载播放请求。
     *
     * @param request 播放请求。
     */
    override suspend fun load(request: PlaybackRequest) {
        withContext(dispatchers.playback) {
            mutableState.value = PlayerState.Loading
            lastSnapshot = request.toSnapshot()
            // 首次下发播放请求时直接起播，详情页预览播放器不能停在暂停快照。
            mutableState.value = PlayerState.Playing(snapshot = lastSnapshot ?: return@withContext)
            commandBus.send(WebViewPlayerCommand.Play)
        }
    }

    /** 开始播放。 */
    override suspend fun play() {
        withContext(dispatchers.playback) {
            lastSnapshot?.let { snapshot ->
                mutableState.value = PlayerState.Playing(snapshot)
                commandBus.send(WebViewPlayerCommand.Play)
            }
        }
    }

    /** 暂停播放。 */
    override suspend fun pause() {
        withContext(dispatchers.playback) {
            mutableState.value = PlayerState.Paused(snapshot = lastSnapshot)
            commandBus.send(WebViewPlayerCommand.Pause)
        }
    }

    /**
     * 跳转到指定位置。
     *
     * @param positionMs 目标播放位置。
     */
    override suspend fun seekTo(positionMs: Long) {
        withContext(dispatchers.playback) {
            lastSnapshot = lastSnapshot?.copy(positionMs = positionMs)
            syncStateWithSnapshot()
            commandBus.send(WebViewPlayerCommand.SeekTo(positionMs = positionMs))
        }
    }

    /**
     * 设置 WebView 播放倍速。
     *
     * @param speed 目标倍速。
     */
    override suspend fun setPlaybackSpeed(speed: Float) {
        withContext(dispatchers.playback) {
            lastSnapshot = lastSnapshot?.copy(playbackSpeed = speed)
            syncStateWithSnapshot()
            commandBus.send(WebViewPlayerCommand.SetPlaybackSpeed(speed))
        }
    }

    /**
     * 设置 WebView 画面比例。
     *
     * @param resizeMode 目标画面比例。
     */
    override suspend fun setResizeMode(resizeMode: TvResizeMode) {
        withContext(dispatchers.playback) {
            lastSnapshot = lastSnapshot?.copy(resizeMode = resizeMode)
            syncStateWithSnapshot()
            commandBus.send(WebViewPlayerCommand.SetResizeMode(resizeMode))
        }
    }

    /** 捕获当前播放快照。 */
    override suspend fun captureSnapshot(): PlaybackSnapshot = withContext(dispatchers.playback) {
        lastSnapshot ?: throw IllegalStateException("尚未加载 WebView 播放请求，无法捕获播放快照")
    }

    /**
     * 恢复播放快照。
     *
     * @param snapshot 播放状态快照。
     */
    override suspend fun restoreSnapshot(snapshot: PlaybackSnapshot) {
        withContext(dispatchers.playback) {
            lastSnapshot = snapshot
            mutableState.value = PlayerState.Paused(snapshot = snapshot)
        }
    }

    /**
     * 接收 WebView 页面上报的真实播放状态。
     *
     * @param event WebView 播放事件。
     */
    fun updateFromWebView(event: WebViewPlaybackEvent) {
        val currentSnapshot = lastSnapshot ?: return
        val nextSnapshot = currentSnapshot.copy(
            positionMs = event.positionMs.coerceAtLeast(0L),
            durationMs = event.durationMs.takeIf { it > 0L } ?: currentSnapshot.durationMs,
            cachedRanges = event.cachedRanges.map { range ->
                PlaybackCachedRange(
                    startMs = range.startMs,
                    endMs = range.endMs,
                )
            },
            networkSpeedBytesPerSecond = event.networkSpeedBytesPerSecond.coerceAtLeast(0L),
        )
        lastSnapshot = nextSnapshot
        mutableState.value = if (event.isPlaying) {
            PlayerState.Playing(snapshot = nextSnapshot)
        } else {
            PlayerState.Paused(snapshot = nextSnapshot)
        }
    }

    /** 释放播放器状态。 */
    override suspend fun release() {
        withContext(dispatchers.playback) {
            lastSnapshot = null
            mutableState.value = PlayerState.Idle
        }
    }

    /**
     * 将播放请求转换为快照。
     *
     * @return 起播快照。
     */
    private fun PlaybackRequest.toSnapshot(): PlaybackSnapshot {
        return PlaybackSnapshot(
            videoId = videoId,
            sourceId = sourceId,
            episodeId = episodeId,
            url = url,
            positionMs = startPositionMs,
            durationMs = 0L,
            playbackSpeed = playbackSpeed,
            resizeMode = resizeMode,
        )
    }

    /**
     * 用最新快照刷新当前播放状态。
     */
    private fun syncStateWithSnapshot() {
        val snapshot = lastSnapshot ?: return
        mutableState.value = when (mutableState.value) {
            is PlayerState.Playing -> PlayerState.Playing(snapshot)
            else -> PlayerState.Paused(snapshot = snapshot)
        }
    }
}
