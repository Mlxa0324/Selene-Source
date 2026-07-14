package org.moontechlab.selene.tv.core.player.exo

import com.google.common.truth.Truth.assertThat
import androidx.media3.common.Player
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.design.threading.DispatcherProvider
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

/**
 * 校验 ExoPlayer 主内核的线程与控制契约。
 */
class ExoPlayerEngineTest {
    /**
     * load 后必须立刻请求底层播放器开始起播，不能只 prepare 后停在假加载态。
     */
    @Test
    fun load_requests_playback_after_media_is_prepared() = runTest {
        val mainDispatcher = StandardTestDispatcher(testScheduler, name = "main")
        val adapter = RecordingExoPlayerAdapter()
        val engine = ExoPlayerEngine(
            player = adapter,
            dispatchers = TestDispatcherProvider(main = mainDispatcher),
        )

        engine.load(
            request = org.moontechlab.selene.tv.core.player.api.PlaybackRequest(
                videoId = "video-1",
                sourceId = "source-a",
                episodeId = "episode-1",
                url = "https://cdn.test/video.m3u8",
            ),
        )
        testScheduler.advanceUntilIdle()

        assertThat(adapter.loadedMediaUrl).isEqualTo("https://cdn.test/video.m3u8")
        assertThat(adapter.playCalls).isEqualTo(1)
        assertThat(adapter.lastLoadStartPositionMs).isEqualTo(0L)
    }

    /**
     * 续播请求必须把 startPositionMs 下发给底层 loadMedia，不能忽略后从头播。
     */
    @Test
    fun load_passes_start_position_to_adapter_for_resume() = runTest {
        val mainDispatcher = StandardTestDispatcher(testScheduler, name = "main")
        val adapter = RecordingExoPlayerAdapter()
        val engine = ExoPlayerEngine(
            player = adapter,
            dispatchers = TestDispatcherProvider(main = mainDispatcher),
        )

        engine.load(
            request = org.moontechlab.selene.tv.core.player.api.PlaybackRequest(
                videoId = "video-1",
                sourceId = "source-a",
                episodeId = "episode-1",
                url = "https://cdn.test/video.m3u8",
                startPositionMs = 125_000L,
            ),
        )
        testScheduler.advanceUntilIdle()

        assertThat(adapter.lastLoadStartPositionMs).isEqualTo(125_000L)
        assertThat(adapter.playCalls).isEqualTo(1)
    }

    /**
     * 底层播放器异步报错时，Exo 内核必须结束 loading 并抛出错误状态。
     */
    @Test
    fun player_error_event_updates_state_to_error() = runTest {
        val mainDispatcher = StandardTestDispatcher(testScheduler, name = "main")
        val adapter = RecordingExoPlayerAdapter()
        val engine = ExoPlayerEngine(
            player = adapter,
            dispatchers = TestDispatcherProvider(main = mainDispatcher),
        )

        engine.load(
            request = org.moontechlab.selene.tv.core.player.api.PlaybackRequest(
                videoId = "video-1",
                sourceId = "source-a",
                episodeId = "episode-1",
                url = "https://cdn.test/video.m3u8",
            ),
        )
        adapter.emitPlayerError("测试源播放失败")
        testScheduler.advanceUntilIdle()

        val state = engine.state.value
        assertThat(state).isInstanceOf(org.moontechlab.selene.tv.core.player.api.PlayerState.Error::class.java)
        assertThat((state as org.moontechlab.selene.tv.core.player.api.PlayerState.Error).message)
            .isEqualTo("测试源播放失败")
    }

    /**
     * 就绪但尚未真正播放时，状态应落在暂停态，不能误报为播放中。
     */
    @Test
    fun ready_event_without_real_playback_updates_state_to_paused() = runTest {
        val mainDispatcher = StandardTestDispatcher(testScheduler, name = "main")
        val adapter = RecordingExoPlayerAdapter().apply {
            testPlaybackState = Player.STATE_READY
            testCurrentPositionMs = 18_000L
            testDurationMs = 240_000L
            testIsPlaying = false
        }
        val engine = ExoPlayerEngine(
            player = adapter,
            dispatchers = TestDispatcherProvider(main = mainDispatcher),
        )

        engine.load(
            request = org.moontechlab.selene.tv.core.player.api.PlaybackRequest(
                videoId = "video-1",
                sourceId = "source-a",
                episodeId = "episode-1",
                url = "https://cdn.test/video.m3u8",
            ),
        )
        adapter.emitPlaybackStateChanged(Player.STATE_READY)
        testScheduler.advanceUntilIdle()

        val state = engine.state.value
        assertThat(state).isInstanceOf(org.moontechlab.selene.tv.core.player.api.PlayerState.Paused::class.java)
        val snapshot = (state as org.moontechlab.selene.tv.core.player.api.PlayerState.Paused).snapshot
        assertThat(snapshot?.positionMs).isEqualTo(18_000L)
        assertThat(snapshot?.durationMs).isEqualTo(240_000L)
    }

    /**
     * seek 操作必须在主线程执行，因为 Media3 ExoPlayer 要求从创建线程访问。
     */
    @Test
    fun seekTo_runs_on_main_dispatcher() = runTest {
        val mainDispatcher = StandardTestDispatcher(testScheduler, name = "main")
        val adapter = RecordingExoPlayerAdapter()
        val engine = ExoPlayerEngine(
            player = adapter,
            dispatchers = TestDispatcherProvider(main = mainDispatcher),
        )

        engine.seekTo(positionMs = 92_000L)
        testScheduler.advanceUntilIdle()

        assertThat(adapter.lastSeekPositionMs).isEqualTo(92_000L)
        assertThat(adapter.seekContext?.toString()).contains("main")
    }
}

/**
 * 记录 ExoPlayer 调用的测试替身。
 */
private class RecordingExoPlayerAdapter : ExoPlayerAdapter {
    /** 最近一次加载的媒体地址。 */
    var loadedMediaUrl: String? = null

    /** play 调用次数。 */
    var playCalls: Int = 0

    /** 最近一次 seek 的目标位置。 */
    var lastSeekPositionMs: Long? = null

    /** 最近一次 seek 所在协程上下文。 */
    var seekContext: Any? = null

    /** 模拟当前播放状态。 */
    var testPlaybackState: Int = Player.STATE_IDLE

    /** 模拟当前播放位置。 */
    var testCurrentPositionMs: Long = 0L

    /** 模拟当前总时长。 */
    var testDurationMs: Long = 0L

    /** 模拟当前是否正在播放。 */
    var testIsPlaying: Boolean = false

    /** 当前事件回调。 */
    private var eventCallback: ExoPlayerEventCallback? = null

    /**
     * 记录媒体加载地址。
     *
     * @param url 媒体地址。
     */
    /** 最近一次 load 的起播位置。 */
    var lastLoadStartPositionMs: Long = 0L

    override suspend fun loadMedia(url: String, startPositionMs: Long) {
        loadedMediaUrl = url
        lastLoadStartPositionMs = startPositionMs
    }

    /** 返回 null ExoPlayer 供测试。 */
    override fun getExoPlayer(): androidx.media3.exoplayer.ExoPlayer {
        throw UnsupportedOperationException("测试适配器不提供真实 ExoPlayer")
    }

    /**
     * 记录 seek 调用。
     *
     * @param positionMs 目标播放位置。
     */
    override suspend fun seekTo(positionMs: Long) {
        lastSeekPositionMs = positionMs
        seekContext = currentCoroutineContext()
    }

    /** 记录播放调用。 */
    override suspend fun play() {
        playCalls += 1
    }

    /** 暂停测试空实现。 */
    override suspend fun pause() = Unit

    /** 倍速测试空实现。 */
    override suspend fun setPlaybackSpeed(speed: Float) = Unit

    /** 画面比例测试空实现。 */
    override suspend fun setResizeMode(resizeMode: TvResizeMode) = Unit

    /** 绑定事件回调。 */
    override fun setEventCallback(callback: ExoPlayerEventCallback?) {
        eventCallback = callback
    }

    override fun bindResizeModeApplier(applier: ExoResizeModeApplier) = Unit

    /** 返回当前播放状态。 */
    override fun getPlaybackState(): Int = testPlaybackState

    /** 返回当前播放位置。 */
    override fun getCurrentPositionMs(): Long = testCurrentPositionMs

    /** 返回当前总时长。 */
    override fun getDurationMs(): Long = testDurationMs

    /** 返回当前是否播放中。 */
    override fun isCurrentlyPlaying(): Boolean = testIsPlaying

    /** 释放测试空实现。 */
    override suspend fun release() = Unit

    /**
     * 主动推送播放状态事件。
     *
     * @param state 目标播放状态。
     */
    fun emitPlaybackStateChanged(state: Int) {
        testPlaybackState = state
        eventCallback?.onPlaybackStateChanged(state)
    }

    /**
     * 主动推送播放器错误事件。
     *
     * @param message 错误文案。
     */
    fun emitPlayerError(message: String) {
        eventCallback?.onPlayerError(message, IllegalStateException(message))
    }
}

/**
 * 为 ExoPlayer 单元测试提供可控调度器。
 */
private class TestDispatcherProvider(
    override val main: CoroutineDispatcher,
) : DispatcherProvider {
    /** 模拟播放域调度器。 */
    override val playback: CoroutineDispatcher = StandardTestDispatcher()

    /** 模拟 IO 调度器。 */
    override val io: CoroutineDispatcher = StandardTestDispatcher()

    /** 模拟默认后台调度器。 */
    override val default: CoroutineDispatcher = StandardTestDispatcher()
}
