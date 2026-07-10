package org.moontechlab.selene.tv.app

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSnapshot
import org.moontechlab.selene.tv.core.player.api.PlaybackSource
import org.moontechlab.selene.tv.core.player.api.PlaybackEpisode
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState
import org.moontechlab.selene.tv.core.player.api.TvResizeMode
import org.moontechlab.selene.tv.feature.detail.TvDetailViewModel

/**
 * 校验 TV 共享播放器宿主的会话复用与释放边界。
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TvSharedPlayerHostTest {
    /**
     * 同一内核重复打开时，宿主必须复用同一份播放器会话。
     */
    @Test
    fun openOrReuseSession_reuses_existing_session_for_same_kernel() {
        val host = TvSharedPlayerHost(
            createExoSession = { createSession(kernel = "exo") },
            createWebViewSession = { createSession(kernel = "webview") },
        )

        val firstSession = host.openOrReuseSession(kernel = "webview")
        val secondSession = host.openOrReuseSession(kernel = "webview")

        assertThat(secondSession).isSameInstanceAs(firstSession)
        assertThat(host.currentKernel).isEqualTo("webview")
        assertThat(host.currentSession).isSameInstanceAs(firstSession)
    }

    /**
     * 共享宿主必须统一持有当前播放上下文，避免详情页和全屏页各存一份。
     */
    @Test
    fun updatePlaybackContext_keeps_latest_playback_context() {
        val host = TvSharedPlayerHost(
            createExoSession = { createSession(kernel = "exo") },
            createWebViewSession = { createSession(kernel = "webview") },
        )
        val request = PlaybackRequest(
            videoId = "video-1",
            videoTitle = "测试影片",
            sourceId = "source-a",
            episodeId = "episode-1",
            episodeIndex = 0,
            episodeTitle = "第 1 集",
            url = "https://cdn.test/video-1.m3u8",
            startPositionMs = 12_000L,
        )
        val sources = listOf(PlaybackSource(id = "source-a", name = "线路 A"))
        val episodes = listOf(PlaybackEpisode(id = "episode-1", title = "第 1 集"))

        host.updatePlaybackContext(
            request = request,
            sources = sources,
            episodes = episodes,
        )

        assertThat(host.currentContext).isEqualTo(
            TvSharedPlaybackContext(
                request = request,
                sources = sources,
                episodes = episodes,
            ),
        )
    }

    /**
     * 同一详情页返回时必须复用原来的状态机，避免已经加载好的线路和选集状态被重建。
     */
    @Test
    fun openOrReuseDetailViewModel_reuses_existing_detail_session_for_same_key() {
        val host = TvSharedPlayerHost(
            createExoSession = { createSession(kernel = "exo") },
            createWebViewSession = { createSession(kernel = "webview") },
        )

        val firstViewModel = host.openOrReuseDetailViewModel(detailKey = "source-a::video-1::webview") {
            TvDetailViewModel()
        }
        val secondViewModel = host.openOrReuseDetailViewModel(detailKey = "source-a::video-1::webview") {
            TvDetailViewModel()
        }

        assertThat(secondViewModel).isSameInstanceAs(firstViewModel)
    }

    /**
     * 离开播放流后，宿主必须统一释放缓存会话并清空播放上下文。
     */
    @Test
    fun clearPlaybackFlow_releases_cached_sessions_and_context() = runTest {
        val exoEngine = RecordingHostPlayerEngine()
        val webViewEngine = RecordingHostPlayerEngine()
        val host = TvSharedPlayerHost(
            createExoSession = { createSession(kernel = "exo", engine = exoEngine) },
            createWebViewSession = { createSession(kernel = "webview", engine = webViewEngine) },
        )
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "episode-1",
            url = "https://cdn.test/video-1.m3u8",
        )

        host.openOrReuseSession(kernel = "exo")
        host.openOrReuseSession(kernel = "webview")
        host.updatePlaybackContext(request = request)

        host.clearPlaybackFlow()

        assertThat(host.currentKernel).isNull()
        assertThat(host.currentSession).isNull()
        assertThat(host.currentContext).isNull()
        assertThat(exoEngine.releaseCalls).isEqualTo(1)
        assertThat(webViewEngine.releaseCalls).isEqualTo(1)
    }

    /**
     * 构造共享播放器会话测试数据。
     *
     * @param kernel 会话所属播放内核。
     * @param engine 会话绑定的播放器内核。
     * @return 共享播放器会话。
     */
    private fun createSession(
        kernel: String,
        engine: PlayerEngine = RecordingHostPlayerEngine(),
    ): TvSharedPlayerSession {
        return TvSharedPlayerSession(
            kernel = kernel,
            playerEngine = engine,
        )
    }
}

/**
 * 共享播放器宿主测试用播放器内核。
 */
private class RecordingHostPlayerEngine : PlayerEngine {
    /** 当前内核状态。 */
    private val mutableState = MutableStateFlow<PlayerState>(PlayerState.Idle)

    /** 对外暴露的状态流。 */
    override val state: StateFlow<PlayerState> = mutableState

    /** 释放调用次数。 */
    var releaseCalls: Int = 0

    /** load 测试空实现。 */
    override suspend fun load(request: PlaybackRequest) = Unit

    /** play 测试空实现。 */
    override suspend fun play() = Unit

    /** pause 测试空实现。 */
    override suspend fun pause() = Unit

    /** seek 测试空实现。 */
    override suspend fun seekTo(positionMs: Long) = Unit

    /** 倍速测试空实现。 */
    override suspend fun setPlaybackSpeed(speed: Float) = Unit

    /** 比例测试空实现。 */
    override suspend fun setResizeMode(resizeMode: TvResizeMode) = Unit

    /** 快照测试空实现。 */
    override suspend fun captureSnapshot(): PlaybackSnapshot {
        error("共享宿主测试不需要播放快照")
    }

    /** 恢复测试空实现。 */
    override suspend fun restoreSnapshot(snapshot: PlaybackSnapshot) = Unit

    /** 记录释放次数。 */
    override suspend fun release() {
        releaseCalls += 1
    }
}
