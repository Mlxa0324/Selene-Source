package org.moontechlab.selene.tv.core.player.exo

import android.content.Context
import androidx.media3.exoplayer.ExoPlayer

/**
 * ExoPlayer 创建工厂。
 */
object ExoPlayerFactory {
    /**
     * 创建默认 ExoPlayer 实例。
     *
     * @param context Android 上下文。
     * @return ExoPlayer 控制适配器。
     */
    fun create(context: Context): ExoPlayerAdapter {
        // 首期使用默认构造，后续再补 HLS 缓冲和缓存策略。
        val exoPlayer = ExoPlayer.Builder(context).build()
        return AndroidExoPlayerAdapter(exoPlayer = exoPlayer)
    }
}

/**
 * Android Media3 ExoPlayer 适配器。
 *
 * @property exoPlayer Media3 播放器实例。
 */
class AndroidExoPlayerAdapter(
    private val exoPlayer: ExoPlayer,
) : ExoPlayerAdapter {
    /**
     * 跳转到指定播放位置。
     *
     * @param positionMs 目标播放位置，单位毫秒。
     */
    override suspend fun seekTo(positionMs: Long) {
        exoPlayer.seekTo(positionMs)
    }

    /** 开始播放。 */
    override suspend fun play() {
        exoPlayer.play()
    }

    /** 暂停播放。 */
    override suspend fun pause() {
        exoPlayer.pause()
    }

    /** 释放播放器资源。 */
    override suspend fun release() {
        exoPlayer.release()
    }
}
