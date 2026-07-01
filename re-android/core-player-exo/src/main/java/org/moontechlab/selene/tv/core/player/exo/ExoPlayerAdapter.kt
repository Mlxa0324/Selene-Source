package org.moontechlab.selene.tv.core.player.exo

import org.moontechlab.selene.tv.core.player.api.TvResizeMode

/**
 * ExoPlayer 控制适配接口。
 */
interface ExoPlayerAdapter {
    /**
     * 跳转到指定播放位置。
     *
     * @param positionMs 目标播放位置，单位毫秒。
     */
    suspend fun seekTo(positionMs: Long)

    /** 开始播放。 */
    suspend fun play()

    /** 暂停播放。 */
    suspend fun pause()

    /**
     * 设置播放倍速。
     *
     * @param speed 目标倍速。
     */
    suspend fun setPlaybackSpeed(speed: Float)

    /**
     * 设置画面比例。
     *
     * @param resizeMode 目标画面比例。
     */
    suspend fun setResizeMode(resizeMode: TvResizeMode)

    /** 释放播放器资源。 */
    suspend fun release()
}
