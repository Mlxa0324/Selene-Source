package org.moontechlab.selene.tv.core.player.webview

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import org.moontechlab.selene.tv.core.design.threading.DispatcherProvider
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSnapshot
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState

/**
 * WebView 兜底播放内核。
 *
 * @property dispatchers TV 协程调度器分层。
 */
class WebViewPlayerEngine(
    private val dispatchers: DispatcherProvider,
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
            mutableState.value = PlayerState.Paused(snapshot = lastSnapshot)
        }
    }

    /** 开始播放。 */
    override suspend fun play() {
        withContext(dispatchers.playback) {
            lastSnapshot?.let { snapshot -> mutableState.value = PlayerState.Playing(snapshot) }
        }
    }

    /** 暂停播放。 */
    override suspend fun pause() {
        withContext(dispatchers.playback) {
            mutableState.value = PlayerState.Paused(snapshot = lastSnapshot)
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
}
