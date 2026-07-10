package uk.oxiang.ivy.tv.core.player.exo

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import uk.oxiang.ivy.tv.core.player.api.TvResizeMode

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
        // 首期使用默认构造，HLS 缓冲和缓存策略按播放内核配置扩展。
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
    private val resizeModeApplier: ExoResizeModeApplier = ExoResizeModeApplier.Noop,
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

    /**
     * 设置 ExoPlayer 播放倍速。
     *
     * @param speed 目标倍速。
     */
    override suspend fun setPlaybackSpeed(speed: Float) {
        exoPlayer.playbackParameters = PlaybackParameters(speed)
    }

    /**
     * 设置 ExoPlayer 承载视图的画面比例。
     *
     * @param resizeMode 目标画面比例。
     */
    override suspend fun setResizeMode(resizeMode: TvResizeMode) {
        resizeModeApplier.applyResizeMode(resizeMode)
    }

    /** 释放播放器资源。 */
    override suspend fun release() {
        exoPlayer.release()
    }
}

/**
 * ExoPlayer 画面比例应用器。
 */
fun interface ExoResizeModeApplier {
    /**
     * 应用目标画面比例。
     *
     * @param resizeMode 目标 TV 画面比例。
     */
    fun applyResizeMode(resizeMode: TvResizeMode)

    companion object {
        /** 未绑定 PlayerView 时的安全空实现。 */
        val Noop = ExoResizeModeApplier { }
    }
}

/**
 * Media3 PlayerView 画面比例应用器。
 *
 * @property playerView 播放器承载视图。
 */
class PlayerViewResizeModeApplier(
    private val playerView: PlayerView,
) : ExoResizeModeApplier {
    /**
     * 将 TV 画面比例下发到 PlayerView。
     *
     * @param resizeMode 目标 TV 画面比例。
     */
    @OptIn(UnstableApi::class)
    override fun applyResizeMode(resizeMode: TvResizeMode) {
        playerView.resizeMode = resizeMode.toAspectRatioResizeMode()
    }
}

/**
 * 将 TV 画面比例协议映射为 Media3 PlayerView resizeMode。
 *
 * @return Media3 AspectRatioFrameLayout resizeMode 常量。
 */
@OptIn(UnstableApi::class)
internal fun TvResizeMode.toAspectRatioResizeMode(): Int {
    return when (this) {
        TvResizeMode.FIT -> AspectRatioFrameLayout.RESIZE_MODE_FIT
        TvResizeMode.FILL -> AspectRatioFrameLayout.RESIZE_MODE_FILL
        TvResizeMode.WIDTH -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH
        TvResizeMode.HEIGHT -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_HEIGHT
    }
}
