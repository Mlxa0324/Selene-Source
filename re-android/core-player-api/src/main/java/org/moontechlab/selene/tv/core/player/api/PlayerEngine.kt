package org.moontechlab.selene.tv.core.player.api

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
