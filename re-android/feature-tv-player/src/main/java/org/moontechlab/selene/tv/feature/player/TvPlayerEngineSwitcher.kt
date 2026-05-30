package org.moontechlab.selene.tv.feature.player

import kotlinx.coroutines.withContext
import org.moontechlab.selene.tv.core.design.threading.DispatcherProvider
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSnapshot
import org.moontechlab.selene.tv.core.player.api.PlayerEngine

/**
 * TV 播放内核类型。
 */
enum class PlayerKernel {
    /** ExoPlayer 主内核。 */
    EXO_PLAYER,

    /** WebView 兜底内核。 */
    WEB_VIEW,
}

/**
 * TV 播放器内核切换器。
 *
 * @property exoEngine ExoPlayer 主内核。
 * @property webViewEngine WebView 兜底内核。
 * @property dispatchers TV 协程调度器分层。
 */
class TvPlayerEngineSwitcher(
    private val exoEngine: PlayerEngine,
    private val webViewEngine: PlayerEngine,
    private val dispatchers: DispatcherProvider,
) {
    /** 当前活跃内核。 */
    private var activeEngine: PlayerEngine = exoEngine

    /** 当前活跃内核类型。 */
    var activeKernel: PlayerKernel = PlayerKernel.EXO_PLAYER
        private set

    /**
     * 切换到目标播放内核。
     *
     * @param target 目标内核。
     */
    suspend fun switchTo(target: PlayerKernel) {
        withContext(dispatchers.playback) {
            if (target == activeKernel) {
                // 同内核重复点击不做重载，避免全屏画面无意义闪烁。
                return@withContext
            }

            val currentSnapshot = activeEngine.captureSnapshot()
            val nextEngine = target.engine()
            nextEngine.load(currentSnapshot.toPlaybackRequest())
            nextEngine.restoreSnapshot(currentSnapshot)
            activeEngine.release()
            activeEngine = nextEngine
            activeKernel = target
        }
    }

    /**
     * 根据类型选择播放器内核。
     *
     * @return 目标播放器内核。
     */
    private fun PlayerKernel.engine(): PlayerEngine {
        return when (this) {
            PlayerKernel.EXO_PLAYER -> exoEngine
            PlayerKernel.WEB_VIEW -> webViewEngine
        }
    }

    /**
     * 将播放快照转换为加载请求。
     *
     * @return 播放请求。
     */
    private fun PlaybackSnapshot.toPlaybackRequest(): PlaybackRequest {
        return PlaybackRequest(
            videoId = videoId,
            sourceId = sourceId,
            episodeId = episodeId,
            url = url,
            startPositionMs = positionMs,
            playbackSpeed = playbackSpeed,
            resizeMode = resizeMode,
        )
    }
}
