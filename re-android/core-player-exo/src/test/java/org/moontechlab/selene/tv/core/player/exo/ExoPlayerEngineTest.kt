package org.moontechlab.selene.tv.core.player.exo

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.design.threading.DispatcherProvider

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
