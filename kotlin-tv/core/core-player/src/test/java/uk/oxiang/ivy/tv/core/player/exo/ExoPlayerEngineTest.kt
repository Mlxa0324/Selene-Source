package uk.oxiang.ivy.tv.core.player.exo

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Test
import uk.oxiang.ivy.tv.core.design.util.DispatcherProvider
import uk.oxiang.ivy.tv.core.player.api.PlaybackRequest
import uk.oxiang.ivy.tv.core.player.api.PlaybackSnapshot
import uk.oxiang.ivy.tv.core.player.api.PlayerState
import uk.oxiang.ivy.tv.core.player.api.TvResizeMode

/**
 * 校验 ExoPlayer 主内核的线程与控制契约。
 */
class ExoPlayerEngineTest {
    /**
     * seek 操作必须切到 playback 调度器执行，避免主线程卡顿。
     */
    @Test
    fun seekTo_runs_on_playback_dispatcher() = runTest {
        val playbackDispatcher = StandardTestDispatcher(testScheduler, name = "playback")
        val adapter = RecordingExoPlayerAdapter()
        val engine = ExoPlayerEngine(
            player = adapter,
            dispatchers = TestDispatcherProvider(playback = playbackDispatcher),
        )

        engine.seekTo(positionMs = 92_000L)
        testScheduler.advanceUntilIdle()

        assertThat(adapter.lastSeekPositionMs).isEqualTo(92_000L)
        assertThat(adapter.seekContext?.toString()).contains("playback")
    }

    /**
     * load 之后必须先进入 Loading，再落到携带快照的 Paused 状态。
     */
    @Test
    fun load_transitionsToPaused_withSnapshotFromRequest() = runTest {
        val playbackDispatcher = StandardTestDispatcher(testScheduler, name = "playback")
        val engine = ExoPlayerEngine(
            player = RecordingExoPlayerAdapter(),
            dispatchers = TestDispatcherProvider(playback = playbackDispatcher),
        )

        engine.load(
            PlaybackRequest(
                videoId = "video-1",
                sourceId = "source-1",
                episodeId = "ep-1",
                url = "https://example.com/ep1.m3u8",
                startPositionMs = 5_000L,
            ),
        )
        testScheduler.advanceUntilIdle()

        val state = engine.state.value
        assertThat(state).isInstanceOf(PlayerState.Paused::class.java)
        val snapshot = (state as PlayerState.Paused).snapshot
        assertThat(snapshot?.videoId).isEqualTo("video-1")
        assertThat(snapshot?.positionMs).isEqualTo(5_000L)
    }

    /**
     * play 之后状态必须切换为携带最新快照的 Playing。
     */
    @Test
    fun play_afterLoad_transitionsToPlaying() = runTest {
        val playbackDispatcher = StandardTestDispatcher(testScheduler, name = "playback")
        val engine = ExoPlayerEngine(
            player = RecordingExoPlayerAdapter(),
            dispatchers = TestDispatcherProvider(playback = playbackDispatcher),
        )

        engine.load(
            PlaybackRequest(
                videoId = "video-1",
                sourceId = "source-1",
                episodeId = "ep-1",
                url = "https://example.com/ep1.m3u8",
            ),
        )
        engine.play()
        testScheduler.advanceUntilIdle()

        assertThat(engine.state.value).isInstanceOf(PlayerState.Playing::class.java)
    }

    /**
     * captureSnapshot 在未 load 时必须抛出异常，避免上层拿到空快照静默失败。
     */
    @Test
    fun captureSnapshot_withoutLoad_throwsIllegalStateException() = runTest {
        val playbackDispatcher = StandardTestDispatcher(testScheduler, name = "playback")
        val engine = ExoPlayerEngine(
            player = RecordingExoPlayerAdapter(),
            dispatchers = TestDispatcherProvider(playback = playbackDispatcher),
        )

        var thrown: Throwable? = null
        try {
            engine.captureSnapshot()
        } catch (throwable: IllegalStateException) {
            thrown = throwable
        }

        assertThat(thrown).isNotNull()
    }

    /**
     * restoreSnapshot 必须下发底层 seek 并落到携带该快照的 Paused 状态，
     * 用于切内核后恢复线路/剧集/进度/倍速/画面比例。
     */
    @Test
    fun restoreSnapshot_seeksUnderlyingPlayer_andRestoresPausedState() = runTest {
        val playbackDispatcher = StandardTestDispatcher(testScheduler, name = "playback")
        val adapter = RecordingExoPlayerAdapter()
        val engine = ExoPlayerEngine(
            player = adapter,
            dispatchers = TestDispatcherProvider(playback = playbackDispatcher),
        )
        val snapshot = PlaybackSnapshot(
            videoId = "video-2",
            sourceId = "source-2",
            episodeId = "ep-3",
            url = "https://example.com/ep3.m3u8",
            positionMs = 61_000L,
            durationMs = 120_000L,
            playbackSpeed = 1.5f,
            resizeMode = TvResizeMode.FILL,
        )

        engine.restoreSnapshot(snapshot)
        testScheduler.advanceUntilIdle()

        assertThat(adapter.lastSeekPositionMs).isEqualTo(61_000L)
        val state = engine.state.value
        assertThat(state).isInstanceOf(PlayerState.Paused::class.java)
        assertThat((state as PlayerState.Paused).snapshot).isEqualTo(snapshot)
    }
}

/**
 * 记录 ExoPlayer 调用的测试替身。
 */
private class RecordingExoPlayerAdapter : ExoPlayerAdapter {
    /** 最近一次 seek 的目标位置。 */
    var lastSeekPositionMs: Long? = null

    /** 最近一次 seek 所在协程上下文。 */
    var seekContext: Any? = null

    /**
     * 记录 seek 调用。
     *
     * @param positionMs 目标播放位置。
     */
    override suspend fun seekTo(positionMs: Long) {
        lastSeekPositionMs = positionMs
        seekContext = currentCoroutineContext()
    }

    /** 播放测试空实现。 */
    override suspend fun play() = Unit

    /** 暂停测试空实现。 */
    override suspend fun pause() = Unit

    /** 倍速测试空实现。 */
    override suspend fun setPlaybackSpeed(speed: Float) = Unit

    /** 画面比例测试空实现。 */
    override suspend fun setResizeMode(resizeMode: TvResizeMode) = Unit

    /** 释放测试空实现。 */
    override suspend fun release() = Unit
}

/**
 * 为 ExoPlayer 单元测试提供可控调度器。
 */
private class TestDispatcherProvider(
    override val playback: CoroutineDispatcher,
) : DispatcherProvider {
    /** 模拟主线程调度器。 */
    override val main: CoroutineDispatcher = StandardTestDispatcher()

    /** 模拟 IO 调度器。 */
    override val io: CoroutineDispatcher = StandardTestDispatcher()

    /** 模拟默认后台调度器。 */
    override val default: CoroutineDispatcher = StandardTestDispatcher()
}
