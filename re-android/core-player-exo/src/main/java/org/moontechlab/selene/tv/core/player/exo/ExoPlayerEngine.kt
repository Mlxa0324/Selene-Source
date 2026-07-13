package org.moontechlab.selene.tv.core.player.exo

import androidx.media3.common.Player
import androidx.media3.ui.PlayerView
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import org.moontechlab.selene.tv.core.design.threading.DispatcherProvider
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSnapshot
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

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
    /** 底层 ExoPlayer 实例，供 SurfaceView 绑定。 */
    val exoPlayer get() = player.getExoPlayer()

    /** 当前播放器内部状态。 */
    private val mutableState = MutableStateFlow<PlayerState>(PlayerState.Idle)

    /** 最近一次播放快照。 */
    private var lastSnapshot: PlaybackSnapshot? = null

    /** 当前播放器状态。 */
    override val state: StateFlow<PlayerState> = mutableState

    /** ExoPlayer 事件监听器。 */
    private val playerEventCallback = object : ExoPlayerEventCallback {
        /**
         * 底层状态切换时刷新加载/暂停/播放结束状态。
         *
         * @param playbackState Media3 状态常量。
         */
        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_BUFFERING -> {
                    mutableState.value = PlayerState.Loading
                }

                Player.STATE_READY -> {
                    val snapshot = refreshSnapshotFromPlayer() ?: return
                    mutableState.value = if (player.isCurrentlyPlaying()) {
                        PlayerState.Playing(snapshot)
                    } else {
                        PlayerState.Paused(snapshot = snapshot)
                    }
                }

                Player.STATE_ENDED -> {
                    val snapshot = refreshSnapshotFromPlayer() ?: return
                    val endedSnapshot = snapshot.copy(positionMs = snapshot.durationMs)
                    lastSnapshot = endedSnapshot
                    mutableState.value = PlayerState.Paused(snapshot = endedSnapshot)
                }

                Player.STATE_IDLE -> {
                    // Idle 只在释放或尚未真正准备完成时出现，不主动覆盖已有错误态。
                    if (mutableState.value !is PlayerState.Error) {
                        mutableState.value = PlayerState.Idle
                    }
                }
            }
        }

        /**
         * 真实播放/暂停切换时同步快照状态。
         *
         * @param isPlaying 当前是否真实播放中。
         */
        override fun onIsPlayingChanged(isPlaying: Boolean) {
            val snapshot = refreshSnapshotFromPlayer() ?: return
            mutableState.value = if (isPlaying) {
                PlayerState.Playing(snapshot)
            } else {
                PlayerState.Paused(snapshot = snapshot)
            }
        }

        /**
         * 位置跳变时同步快照，避免 seek 后 UI 停在旧时间。
         *
         * @param positionMs 最新播放位置。
         */
        override fun onPositionDiscontinuity(positionMs: Long) {
            val snapshot = lastSnapshot ?: return
            lastSnapshot = snapshot.copy(positionMs = positionMs.coerceAtLeast(0L))
            syncStateWithSnapshot()
        }

        /**
         * 异步播放失败时转为错误状态，终止无限 loading。
         *
         * @param message 错误文案。
         * @param cause 原始异常。
         */
        override fun onPlayerError(
            message: String,
            cause: Throwable?,
        ) {
            mutableState.value = PlayerState.Error(
                message = message,
                cause = cause,
            )
        }
    }

    /**
     * 加载播放请求。
     *
     * @param request 播放请求。
     */
    override suspend fun load(request: PlaybackRequest) {
        withContext(dispatchers.main) {
            mutableState.value = PlayerState.Loading
            lastSnapshot = request.toSnapshot()
            player.setEventCallback(playerEventCallback)
            player.loadMedia(request.url)
            // Exo 首播必须显式 play，不能只 prepare 后等外部确认键。
            player.play()
        }
    }

    /** 开始播放。 */
    override suspend fun play() {
        withContext(dispatchers.main) {
            player.play()
            lastSnapshot?.let { snapshot -> mutableState.value = PlayerState.Playing(snapshot) }
        }
    }

    /** 暂停播放。 */
    override suspend fun pause() {
        withContext(dispatchers.main) {
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
        withContext(dispatchers.main) {
            // seek 属于播放域任务，避免遥控器长按时阻塞 Compose 主线程。
            player.seekTo(positionMs)
            lastSnapshot = lastSnapshot?.copy(positionMs = positionMs)
        }
    }

    /**
     * 设置播放倍速。
     *
     * @param speed 目标倍速。
     */
    override suspend fun setPlaybackSpeed(speed: Float) {
        withContext(dispatchers.main) {
            player.setPlaybackSpeed(speed)
            lastSnapshot = lastSnapshot?.copy(playbackSpeed = speed)
            syncStateWithSnapshot()
        }
    }

    /**
     * 设置画面比例。
     *
     * @param resizeMode 目标画面比例。
     */
    override suspend fun setResizeMode(resizeMode: TvResizeMode) {
        withContext(dispatchers.main) {
            player.setResizeMode(resizeMode)
            lastSnapshot = lastSnapshot?.copy(resizeMode = resizeMode)
            syncStateWithSnapshot()
        }
    }

    /**
     * 绑定 / 解绑 Media3 PlayerView，使画面比例设置真正落到渲染层。
     *
     * @param playerView 当前活跃 PlayerView；传 null 表示解绑。
     */
    fun bindPlayerView(playerView: PlayerView?) {
        val applier = if (playerView == null) {
            ExoResizeModeApplier.Noop
        } else {
            PlayerViewResizeModeApplier(playerView)
        }
        player.bindResizeModeApplier(applier)
        // 绑定后立刻回放当前比例，避免切换画面层后回到默认 FIT。
        val currentMode = lastSnapshot?.resizeMode ?: TvResizeMode.FIT
        applier.applyResizeMode(currentMode)
    }


    /**
     * 捕获当前播放快照。
     *
     * @return 当前播放快照。
     * @throws IllegalStateException 尚未加载播放请求时抛出。
     */
    override suspend fun captureSnapshot(): PlaybackSnapshot = withContext(dispatchers.main) {
        lastSnapshot ?: throw IllegalStateException("尚未加载播放请求，无法捕获播放快照")
    }

    /**
     * 恢复播放快照。
     *
     * @param snapshot 播放状态快照。
     */
    override suspend fun restoreSnapshot(snapshot: PlaybackSnapshot) {
        withContext(dispatchers.main) {
            // 切内核恢复时先保存状态，再让上层触发软重载。
            lastSnapshot = snapshot
            player.seekTo(snapshot.positionMs)
            mutableState.value = PlayerState.Paused(snapshot = snapshot)
        }
    }

    /** 释放播放器资源。 */
    override suspend fun release() {
        withContext(dispatchers.main) {
            player.setEventCallback(null)
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

    /**
     * 用最新快照刷新当前播放状态。
     */
    private fun syncStateWithSnapshot() {
        val snapshot = lastSnapshot ?: return
        mutableState.value = when (mutableState.value) {
            is PlayerState.Playing -> PlayerState.Playing(snapshot)
            is PlayerState.Paused -> PlayerState.Paused(snapshot = snapshot)
            is PlayerState.Error -> mutableState.value
            else -> PlayerState.Playing(snapshot)
        }
    }

    /**
     * 读取底层播放器当前快照。
     *
     * @return 已同步底层时间和时长的快照；尚未加载时返回空。
     */
    private fun refreshSnapshotFromPlayer(): PlaybackSnapshot? {
        val snapshot = lastSnapshot ?: return null
        val duration = player.getDurationMs().coerceAtLeast(0L)
        val position = player.getCurrentPositionMs().coerceAtLeast(0L)
        return snapshot.copy(
            durationMs = duration,
            positionMs = position,
        ).also { refreshed ->
            lastSnapshot = refreshed
        }
    }
}
