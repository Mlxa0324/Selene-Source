package org.moontechlab.selene.tv.feature.player

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.design.threading.DispatcherProvider
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSnapshot
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

/**
 * 校验 TV 播放器内核切换状态机。
 */
class TvPlayerEngineSwitcherTest {
    /**
     * 切到目标内核时应恢复当前播放快照。
     */
    @Test
    fun switchEngine_restores_snapshot_on_target_engine() = runTest {
        val snapshot = PlaybackSnapshot(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-3",
            url = "https://cdn.test/3.m3u8",
            positionMs = 92_000L,
            durationMs = 1_800_000L,
            playbackSpeed = 1.25f,
            resizeMode = TvResizeMode.FIT,
        )
        val fakeExoEngine = FakePlayerEngine(snapshot = snapshot)
        val fakeWebViewEngine = FakePlayerEngine(snapshot = snapshot)
        val switcher = TvPlayerEngineSwitcher(
            exoEngine = fakeExoEngine,
            webViewEngine = fakeWebViewEngine,
            dispatchers = TestDispatcherProvider(StandardTestDispatcher(testScheduler)),
        )

        switcher.switchTo(PlayerKernel.WEB_VIEW)

        assertThat(fakeWebViewEngine.restoredSnapshot?.sourceId).isEqualTo("source-a")
        assertThat(fakeWebViewEngine.restoredSnapshot?.positionMs).isEqualTo(92_000L)
        assertThat(fakeExoEngine.releaseCount).isEqualTo(1)
    }
}

/**
 * 播放器测试替身。
 *
 * @property snapshot 当前快照。
 */
private class FakePlayerEngine(
    private var snapshot: PlaybackSnapshot,
) : PlayerEngine {
    /** 已恢复的快照。 */
    var restoredSnapshot: PlaybackSnapshot? = null

    /** 释放次数。 */
    var releaseCount: Int = 0

    /** 播放器状态。 */
    override val state: StateFlow<PlayerState> = MutableStateFlow(PlayerState.Idle)

    /** 记录加载请求。 */
    override suspend fun load(request: PlaybackRequest) {
        snapshot = snapshot.copy(positionMs = request.startPositionMs)
    }

    /** 播放测试空实现。 */
    override suspend fun play() = Unit

    /** 暂停测试空实现。 */
    override suspend fun pause() = Unit

    /** seek 测试空实现。 */
    override suspend fun seekTo(positionMs: Long) {
        snapshot = snapshot.copy(positionMs = positionMs)
    }

    /** 捕获当前快照。 */
    override suspend fun captureSnapshot(): PlaybackSnapshot = snapshot

    /** 恢复当前快照。 */
    override suspend fun restoreSnapshot(snapshot: PlaybackSnapshot) {
        restoredSnapshot = snapshot
        this.snapshot = snapshot
    }

    /** 记录释放次数。 */
    override suspend fun release() {
        releaseCount += 1
    }
}

/**
 * 切换状态机测试调度器。
 */
private class TestDispatcherProvider(
    override val playback: kotlinx.coroutines.CoroutineDispatcher,
) : DispatcherProvider {
    /** 模拟主线程调度器。 */
    override val main = StandardTestDispatcher()

    /** 模拟 IO 调度器。 */
    override val io = StandardTestDispatcher()

    /** 模拟默认后台调度器。 */
    override val default = StandardTestDispatcher()
}
