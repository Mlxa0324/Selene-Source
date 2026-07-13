package org.moontechlab.selene.tv.core.player.exo

import androidx.media3.exoplayer.ExoPlayer
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

/**
 * ExoPlayer 控制适配接口。
 */
interface ExoPlayerAdapter {
    /**
     * 加载媒体资源。
     *
     * @param url 媒体资源地址。
     */
    suspend fun loadMedia(url: String)

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

    /**
     * 绑定画面比例应用器，通常在 PlayerView 创建后注入。
     *
     * @param applier 画面比例应用器；解绑时传 Noop。
     */
    fun bindResizeModeApplier(applier: ExoResizeModeApplier)

    /**
     * 绑定底层播放器事件回调。
     *
     * @param callback 事件回调；传空时停止向上游转发状态。
     */
    fun setEventCallback(callback: ExoPlayerEventCallback?)

    /**
     * 读取底层播放器当前播放状态。
     *
     * @return Media3 Player 播放状态常量。
     */
    fun getPlaybackState(): Int

    /**
     * 读取底层播放器当前位置。
     *
     * @return 当前播放位置，单位毫秒。
     */
    fun getCurrentPositionMs(): Long

    /**
     * 读取底层播放器总时长。
     *
     * @return 当前媒体时长，未知时允许返回负值。
     */
    fun getDurationMs(): Long

    /**
     * 判断底层播放器是否正在真实播放。
     *
     * @return 已经起播且未暂停时返回 true。
     */
    fun isCurrentlyPlaying(): Boolean

    /**
     * 返回底层 ExoPlayer 实例，供 SurfaceView 绑定。
     *
     * @return 底层 ExoPlayer 实例。
     */
    fun getExoPlayer(): ExoPlayer

    /** 释放播放器资源。 */
    suspend fun release()
}

/**
 * ExoPlayer 事件回调桥。
 */
interface ExoPlayerEventCallback {
    /**
     * 底层播放状态发生变化。
     *
     * @param playbackState Media3 Player 状态常量。
     */
    fun onPlaybackStateChanged(playbackState: Int)

    /**
     * 底层播放/暂停态发生变化。
     *
     * @param isPlaying 当前是否播放中。
     */
    fun onIsPlayingChanged(isPlaying: Boolean)

    /**
     * 底层当前位置发生跳变。
     *
     * @param positionMs 最新播放位置，单位毫秒。
     */
    fun onPositionDiscontinuity(positionMs: Long)

    /**
     * 底层播放器上报错误。
     *
     * @param message 错误文案。
     * @param cause 原始异常。
     */
    fun onPlayerError(
        message: String,
        cause: Throwable?,
    )
}
