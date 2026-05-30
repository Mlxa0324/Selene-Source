package org.moontechlab.selene.tv.core.player.exo

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import org.moontechlab.selene.tv.core.design.threading.DispatcherProvider
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSnapshot
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState

/**
 * ExoPlayer 主播放内核。
 *
 * @property player ExoPlayer 控制适配器。
 * @property dispatchers TV 协程调度器分层。
 */
class ExoPlayerEngine(
    private val player: ExoPlayerAdapter,
    private val dispatchers: DispatcherProvider,
) : PlayerEngine {
    /** 当前播放器内部状态。 */
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
            // 首期先记录快照，真实 MediaItem 加载将在播放页接线时补齐。
            mutableState.value = PlayerState.Loading
            lastSnapshot = request.toSnapshot()
            mutableState.value = PlayerState.Paused(snapshot = lastSnapshot)
        }
    }

    /** 开始播放。 */
    override suspend fun play() {
        withContext(dispatchers.playback) {
            player.play()
            lastSnapshot?.let { snapshot -> mutableState.value = PlayerState.Playing(snapshot) }
        }
    }

    /** 暂停播放。 */
    override suspend fun pause() {
        withContext(dispatchers.playback) {
            player.pause()
            mutableState.value = PlayerState.Paused(snapshot = lastSnapshot)
        }
    }

    /**
     * 跳转到指定播放位置。
     *
     * @param positionMs 目标播放位置，单位毫秒。
     */
    override suspend fun seekTo(positionMs: Long) {
        withContext(dispatchers.playback) {
            // seek 属于播放域任务，避免遥控器长按时阻塞 Compose 主线程。
            player.seekTo(positionMs)
            lastSnapshot = lastSnapshot?.copy(positionMs = positionMs)
        }
    }

    /**
     * 捕获当前播放快照。
     *
     * @return 当前播放快照。
     * @throws IllegalStateException 尚未加载播放请求时抛出。
     */
    override suspend fun captureSnapshot(): PlaybackSnapshot = withContext(dispatchers.playback) {
        lastSnapshot ?: throw IllegalStateException("尚未加载播放请求，无法捕获播放快照")
    }

    /**
     * 恢复播放快照。
     *
     * @param snapshot 播放状态快照。
     */
    override suspend fun restoreSnapshot(snapshot: PlaybackSnapshot) {
        withContext(dispatchers.playback) {
            // 切内核恢复时先保存状态，再让上层触发软重载。
            lastSnapshot = snapshot
            player.seekTo(snapshot.positionMs)
            mutableState.value = PlayerState.Paused(snapshot = snapshot)
        }
    }

    /** 释放播放器资源。 */
    override suspend fun release() {
        withContext(dispatchers.playback) {
            player.release()
            mutableState.value = PlayerState.Idle
            lastSnapshot = null
        }
    }

    /**
     * 将播放请求转换为播放快照。
     *
     * @return 起播状态快照。
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
