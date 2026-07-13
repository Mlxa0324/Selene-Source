package org.moontechlab.selene.tv.core.player.exo

import android.content.Context
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.PlaybackException
import androidx.media3.common.Tracks
import androidx.media3.common.VideoSize
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

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
) : ExoPlayerAdapter {
    /** 当前 PlayerView 画面比例应用器；未绑定画面层时为空实现。 */
    @Volatile
    private var resizeModeApplier: ExoResizeModeApplier = ExoResizeModeApplier.Noop

    /** 当前向上游透出的状态回调。 */
    private var eventCallback: ExoPlayerEventCallback? = null

    /** 底层 Media3 监听器。 */
    private val playerListener = object : Player.Listener {
        /**
         * 同步底层准备/缓冲/结束状态。
         *
         * @param playbackState Media3 状态常量。
         */
        override fun onPlaybackStateChanged(playbackState: Int) {
            Log.d(
                EXO_PLAYER_LOG_TAG,
                "playbackState=${playbackState.toDebugName()} isPlaying=${exoPlayer.isPlaying} " +
                    "positionMs=${exoPlayer.currentPosition.coerceAtLeast(0L)} " +
                    "durationMs=${exoPlayer.duration.coerceAtLeast(0L)}",
            )
            eventCallback?.onPlaybackStateChanged(playbackState)
        }

        /**
         * 同步底层播放/暂停切换。
         *
         * @param isPlaying 当前是否真实播放中。
         */
        override fun onIsPlayingChanged(isPlaying: Boolean) {
            Log.d(
                EXO_PLAYER_LOG_TAG,
                "isPlayingChanged=$isPlaying positionMs=${exoPlayer.currentPosition.coerceAtLeast(0L)} " +
                    "durationMs=${exoPlayer.duration.coerceAtLeast(0L)}",
            )
            eventCallback?.onIsPlayingChanged(isPlaying)
        }

        /**
         * 记录当前选中的音视频轨信息，区分“没有视频轨”和“视频轨已选中但没显示”。
         *
         * @param tracks 当前轨道集合。
         */
        override fun onTracksChanged(tracks: Tracks) {
            Log.d(
                EXO_PLAYER_LOG_TAG,
                "tracksChanged ${tracks.toDebugSummary()}",
            )
        }

        /**
         * 记录底层输出视频尺寸，确认解码后是否真的拿到了视频帧尺寸。
         *
         * @param videoSize 当前视频尺寸。
         */
        override fun onVideoSizeChanged(videoSize: VideoSize) {
            Log.d(
                EXO_PLAYER_LOG_TAG,
                "videoSizeChanged width=${videoSize.width} height=${videoSize.height} " +
                    "ratio=${videoSize.pixelWidthHeightRatio}",
            )
        }

        /**
         * 记录首帧渲染回调，直接判断黑屏时视频首帧是否真正交给宿主层。
         */
        override fun onRenderedFirstFrame() {
            Log.d(EXO_PLAYER_LOG_TAG, "renderedFirstFrame")
        }

        /**
         * 记录 surface 尺寸，辅助判断 TextureView / SurfaceView 宿主是否拿到真实输出尺寸。
         *
         * @param width surface 宽度。
         * @param height surface 高度。
         */
        override fun onSurfaceSizeChanged(width: Int, height: Int) {
            Log.d(
                EXO_PLAYER_LOG_TAG,
                "surfaceSizeChanged width=$width height=$height",
            )
        }

        /**
         * 同步底层位置跳变。
         *
         * @param oldPosition 旧位置。
         * @param newPosition 新位置。
         * @param reason 跳变原因。
         */
        override fun onPositionDiscontinuity(
            oldPosition: Player.PositionInfo,
            newPosition: Player.PositionInfo,
            reason: Int,
        ) {
            eventCallback?.onPositionDiscontinuity(newPosition.positionMs.coerceAtLeast(0L))
        }

        /**
         * 把 Exo 异步播放失败抬升到 Kotlin TV 状态机。
         *
         * @param error Media3 播放异常。
         */
        override fun onPlayerError(error: PlaybackException) {
            Log.e(
                EXO_PLAYER_LOG_TAG,
                "playerError code=${error.errorCodeName} message=${error.localizedMessage ?: error.message}",
                error,
            )
            eventCallback?.onPlayerError(
                message = error.localizedMessage ?: error.message ?: "ExoPlayer 播放失败",
                cause = error,
            )
        }
    }

    init {
        // 适配器创建后立刻绑定一次监听，避免 load 前后的异步状态丢失。
        exoPlayer.addListener(playerListener)
    }

    /**
     * 加载媒体资源。
     *
     * @param url 媒体资源地址。
     */
    override suspend fun loadMedia(url: String) {
        exoPlayer.setMediaItem(MediaItem.fromUri(url))
        exoPlayer.prepare()
    }

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

    /**
     * 绑定画面比例应用器。
     *
     * @param applier 目标应用器。
     */
    override fun bindResizeModeApplier(applier: ExoResizeModeApplier) {
        resizeModeApplier = applier
    }

    /**
     * 绑定 Exo 事件回调。
     *
     * @param callback 上游状态桥。
     */
    override fun setEventCallback(callback: ExoPlayerEventCallback?) {
        eventCallback = callback
    }

    /**
     * 返回当前播放状态。
     *
     * @return Media3 Player 状态常量。
     */
    override fun getPlaybackState(): Int = exoPlayer.playbackState

    /**
     * 返回当前播放位置。
     *
     * @return 当前播放位置，单位毫秒。
     */
    override fun getCurrentPositionMs(): Long = exoPlayer.currentPosition.coerceAtLeast(0L)

    /**
     * 返回当前媒体总时长。
     *
     * @return 已知时长，未知时可能返回负值。
     */
    override fun getDurationMs(): Long = exoPlayer.duration

    /**
     * 返回当前是否真实播放中。
     *
     * @return ExoPlayer 的 isPlaying 状态。
     */
    override fun isCurrentlyPlaying(): Boolean = exoPlayer.isPlaying

    /**
     * 返回底层 ExoPlayer 实例，供 SurfaceView 绑定。
     *
     * @return 底层 ExoPlayer 实例。
     */
    override fun getExoPlayer(): ExoPlayer = exoPlayer

    /** 释放播放器资源。 */
    override suspend fun release() {
        exoPlayer.removeListener(playerListener)
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
    override fun applyResizeMode(resizeMode: TvResizeMode) {
        playerView.resizeMode = resizeMode.toAspectRatioResizeMode()
    }
}

/**
 * 将 TV 画面比例协议映射为 Media3 PlayerView resizeMode。
 *
 * @return Media3 AspectRatioFrameLayout resizeMode 常量。
 */
internal fun TvResizeMode.toAspectRatioResizeMode(): Int {
    return when (this) {
        TvResizeMode.FIT -> AspectRatioFrameLayout.RESIZE_MODE_FIT
        TvResizeMode.FILL -> AspectRatioFrameLayout.RESIZE_MODE_FILL
        TvResizeMode.WIDTH -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_WIDTH
        TvResizeMode.HEIGHT -> AspectRatioFrameLayout.RESIZE_MODE_FIXED_HEIGHT
    }
}

/**
 * 将播放器状态常量转换为便于 adb 排障的短文本。
 *
 * @return 可读状态名。
 */
private fun Int.toDebugName(): String {
    return when (this) {
        Player.STATE_IDLE -> "IDLE"
        Player.STATE_BUFFERING -> "BUFFERING"
        Player.STATE_READY -> "READY"
        Player.STATE_ENDED -> "ENDED"
        else -> "UNKNOWN($this)"
    }
}

/**
 * 汇总当前选中的音视频轨，用于 adb 中快速判断是否真的拿到了视频轨。
 *
 * @return 单行调试摘要。
 */
private fun Tracks.toDebugSummary(): String {
    val selectedTracks = groups.flatMap { group ->
        (0 until group.length).mapNotNull { trackIndex ->
            if (!group.isTrackSelected(trackIndex)) {
                return@mapNotNull null
            }
            val format = group.getTrackFormat(trackIndex)
            "type=${group.getType()} mime=${format.sampleMimeType} codecs=${format.codecs} " +
                "size=${format.width}x${format.height} bitrate=${format.bitrate}"
        }
    }
    return if (selectedTracks.isEmpty()) {
        "selectedTracks=<none>"
    } else {
        "selectedTracks=${selectedTracks.joinToString(" | ")}"
    }
}

/** Exo 播放链路日志标签。 */
private const val EXO_PLAYER_LOG_TAG = "SeleneExoPlayer"
