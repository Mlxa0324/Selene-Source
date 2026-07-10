package uk.oxiang.ivy.tv.core.player.api

import kotlinx.coroutines.flow.StateFlow

/**
 * TV 播放器内核统一协议。
 */
interface PlayerEngine {
    /** 当前播放器状态。 */
    val state: StateFlow<PlayerState>

    /**
     * 加载播放请求。
     *
     * @param request 播放请求。
     */
    suspend fun load(request: PlaybackRequest)

    /** 开始播放。 */
    suspend fun play()

    /** 暂停播放。 */
    suspend fun pause()

    /**
     * 跳转到指定播放位置。
     *
     * @param positionMs 目标播放位置，单位毫秒。
     */
    suspend fun seekTo(positionMs: Long)

    /**
     * 设置当前播放倍速。
     *
     * @param speed 播放倍速，例如 `1.0f` 或 `1.5f`。
     */
    suspend fun setPlaybackSpeed(speed: Float)

    /**
     * 设置当前画面比例模式。
     *
     * @param resizeMode 目标画面比例。
     */
    suspend fun setResizeMode(resizeMode: TvResizeMode)

    /**
     * 捕获当前播放快照。
     *
     * @return 当前播放快照。
     */
    suspend fun captureSnapshot(): PlaybackSnapshot

    /**
     * 恢复播放快照。
     *
     * @param snapshot 播放状态快照。
     */
    suspend fun restoreSnapshot(snapshot: PlaybackSnapshot)

    /** 释放播放器资源。 */
    suspend fun release()
}
