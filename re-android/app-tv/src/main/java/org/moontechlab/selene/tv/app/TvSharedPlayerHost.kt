package org.moontechlab.selene.tv.app

import org.moontechlab.selene.tv.feature.detail.TvDetailViewModel
import org.moontechlab.selene.tv.core.player.api.PlaybackEpisode
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSource
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.exo.ExoPlayerEngine
import org.moontechlab.selene.tv.core.player.webview.WebViewPlayerSession

/**
 * 共享播放器当前播放上下文。
 *
 * @property request 当前播放请求。
 * @property sources 当前可切换线路。
 * @property episodes 当前可切换剧集。
 */
data class TvSharedPlaybackContext(
    val request: PlaybackRequest,
    val sources: List<PlaybackSource> = emptyList(),
    val episodes: List<PlaybackEpisode> = emptyList(),
)

/**
 * 共享播放器会话。
 *
 * @property kernel 当前会话所属播放内核。
 * @property playerEngine 当前会话暴露给业务层的统一播放器内核。
 * @property exoEngine Exo 会话时持有的 Exo 引擎。
 * @property webViewSession WebView 会话时持有的 WebView 播放会话。
 */
class TvSharedPlayerSession(
    val kernel: String,
    val playerEngine: PlayerEngine,
    val exoEngine: ExoPlayerEngine? = null,
    val webViewSession: WebViewPlayerSession? = null,
) {
    /**
     * 释放当前共享会话资源。
     */
    suspend fun release() {
        if (webViewSession != null) {
            // WebView 会话除了播放器内核外，还需要顺手销毁复用的 WebView 页面实例。
            webViewSession.release()
            return
        }
        playerEngine.release()
    }
}

/**
 * TV 导航层共享播放器宿主。
 *
 * 它负责把播放器会话和播放上下文从页面里提升到导航级生命周期：
 * - 详情页和全屏页共用同一份播放器会话
 * - 详情页和全屏页共用同一份播放上下文
 * - 离开整条播放流时统一释放资源
 *
 * @property createExoSession Exo 会话工厂。
 * @property createWebViewSession WebView 会话工厂。
 */
class TvSharedPlayerHost(
    private val createExoSession: () -> TvSharedPlayerSession,
    private val createWebViewSession: () -> TvSharedPlayerSession,
) {
    /** 当前活跃播放内核。 */
    var currentKernel: String? = null
        private set

    /** 当前播放上下文。 */
    var currentContext: TvSharedPlaybackContext? = null
        private set

    /** 已缓存的 Exo 共享会话。 */
    private var exoSession: TvSharedPlayerSession? = null

    /** 已缓存的 WebView 共享会话。 */
    private var webViewSession: TvSharedPlayerSession? = null

    /** 当前活跃共享会话。 */
    val currentSession: TvSharedPlayerSession?
        get() = currentKernel?.let(::peekSession)

    /** 当前播放流里保活的详情页状态机会话。 */
    private val retainedDetailViewModels = linkedMapOf<String, TvDetailViewModel>()

    /**
     * 打开或复用目标内核的共享会话。
     *
     * @param kernel 目标播放内核。
     * @return 目标内核对应的共享会话。
     */
    fun openOrReuseSession(kernel: String): TvSharedPlayerSession {
        val normalizedKernel = kernel.takeIf { it == KERNEL_EXO } ?: KERNEL_WEBVIEW
        currentKernel = normalizedKernel
        return when (normalizedKernel) {
            KERNEL_EXO -> exoSession ?: createExoSession().also { session ->
                exoSession = session
            }

            else -> webViewSession ?: createWebViewSession().also { session ->
                webViewSession = session
            }
        }
    }

    /**
     * 更新当前共享播放上下文。
     *
     * @param request 当前播放请求。
     * @param sources 当前可切换线路。
     * @param episodes 当前可切换剧集。
     */
    fun updatePlaybackContext(
        request: PlaybackRequest,
        sources: List<PlaybackSource> = emptyList(),
        episodes: List<PlaybackEpisode> = emptyList(),
    ) {
        currentContext = TvSharedPlaybackContext(
            request = request,
            sources = sources,
            episodes = episodes,
        )
    }

    /**
     * 打开或复用当前详情页状态机会话。
     *
     * 详情页进入全屏再返回时，需要直接接回原来的双路加载和选中状态，不能重建一个全新的状态机。
     *
     * @param detailKey 当前详情会话标识。
     * @param createViewModel 首次进入时的详情页状态机工厂。
     * @return 详情页状态机。
     */
    fun openOrReuseDetailViewModel(
        detailKey: String,
        createViewModel: () -> TvDetailViewModel,
    ): TvDetailViewModel {
        return retainedDetailViewModels.getOrPut(detailKey, createViewModel)
    }

    /**
     * 清空整条播放流并释放所有缓存会话。
     */
    suspend fun clearPlaybackFlow() {
        currentKernel = null
        currentContext = null
        exoSession?.release()
        webViewSession?.release()
        exoSession = null
        webViewSession = null
        retainedDetailViewModels.values.forEach(TvDetailViewModel::release)
        retainedDetailViewModels.clear()
    }

    /**
     * 按内核窥视缓存会话。
     *
     * @param kernel 播放内核。
     * @return 已缓存共享会话；未创建时返回空。
     */
    private fun peekSession(kernel: String): TvSharedPlayerSession? {
        return when (kernel) {
            KERNEL_EXO -> exoSession
            else -> webViewSession
        }
    }

    private companion object {
        /** Exo 内核标识。 */
        const val KERNEL_EXO = "exo"

        /** WebView 内核标识。 */
        const val KERNEL_WEBVIEW = "webview"
    }
}
