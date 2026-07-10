package uk.oxiang.ivy.tv.core.player.webview

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Test
import uk.oxiang.ivy.tv.core.design.util.DispatcherProvider
import uk.oxiang.ivy.tv.core.player.api.PlaybackRequest
import uk.oxiang.ivy.tv.core.player.api.PlayerState
import uk.oxiang.ivy.tv.core.player.api.TvResizeMode

/**
 * 校验 WebView 播放命令总线。
 */
@OptIn(ExperimentalCoroutinesApi::class)
class WebViewPlayerCommandBusTest {
    /**
     * 首次加载播放请求时必须通知 WebView 页面立即起播，详情页小播放器不能只停在暂停快照。
     */
    @Test
    fun load_emits_webview_play_command_for_initial_preview() = runTest {
        val commandBus = WebViewPlayerCommandBus()
        val engine = createEngine(commandBus)
        val commands = commandBus.recordCommands(this)

        engine.load(sampleRequest())

        assertThat(commands).containsExactly(WebViewPlayerCommand.Play)
        assertThat(engine.state.value).isInstanceOf(PlayerState.Playing::class.java)
    }

    /**
     * 播放内核开始播放时必须通知 WebView 页面执行 play。
     */
    @Test
    fun play_emits_webview_play_command() = runTest {
        val commandBus = WebViewPlayerCommandBus()
        val engine = createEngine(commandBus)
        val commands = commandBus.recordCommands(this)
        engine.load(sampleRequest())
        commands.clear()

        engine.play()

        assertThat(commands).containsExactly(WebViewPlayerCommand.Play)
    }

    /**
     * 播放内核暂停时必须通知 WebView 页面执行 pause。
     */
    @Test
    fun pause_emits_webview_pause_command() = runTest {
        val commandBus = WebViewPlayerCommandBus()
        val engine = createEngine(commandBus)
        val commands = commandBus.recordCommands(this)
        engine.load(sampleRequest())
        commands.clear()

        engine.pause()

        assertThat(commands).containsExactly(WebViewPlayerCommand.Pause)
    }

    /**
     * 播放内核 seek 时必须通知 WebView 页面跳转到真实毫秒位置。
     */
    @Test
    fun seek_emits_webview_seek_command() = runTest {
        val commandBus = WebViewPlayerCommandBus()
        val engine = createEngine(commandBus)
        val commands = commandBus.recordCommands(this)
        engine.load(sampleRequest())
        commands.clear()

        engine.seekTo(45_000L)

        assertThat(commands).containsExactly(WebViewPlayerCommand.SeekTo(positionMs = 45_000L))
    }

    /**
     * 倍速和画面比例必须下发给 WebView 页面，不能只更新 ViewModel 菜单状态。
     */
    @Test
    fun speed_and_resize_emit_webview_commands() = runTest {
        val commandBus = WebViewPlayerCommandBus()
        val engine = createEngine(commandBus)
        val commands = commandBus.recordCommands(this)
        engine.load(sampleRequest())
        commands.clear()

        engine.setPlaybackSpeed(1.5f)

        engine.setResizeMode(TvResizeMode.FILL)

        assertThat(commands).containsExactly(
            WebViewPlayerCommand.SetPlaybackSpeed(1.5f),
            WebViewPlayerCommand.SetResizeMode(TvResizeMode.FILL),
        ).inOrder()
    }

    /**
     * WebView 真实播放事件必须回灌到播放器状态，避免进度条只停留在乐观快照。
     */
    @Test
    fun playback_event_updates_engine_state_from_webview_progress() = runTest {
        val engine = createEngine(WebViewPlayerCommandBus())
        engine.load(sampleRequest())

        engine.updateFromWebView(
            WebViewPlaybackEvent(
                positionMs = 12_000L,
                durationMs = 90_000L,
                isPlaying = true,
                networkSpeedBytesPerSecond = 640_000L,
                cachedRanges = listOf(
                    WebViewCachedRange(startMs = 10_000L, endMs = 60_000L),
                ),
            ),
        )

        val state = engine.state.value as PlayerState.Playing
        assertThat(state.snapshot.positionMs).isEqualTo(12_000L)
        assertThat(state.snapshot.durationMs).isEqualTo(90_000L)
        assertThat(state.snapshot.networkSpeedBytesPerSecond).isEqualTo(640_000L)
        assertThat(state.snapshot.cachedRanges.first().startMs).isEqualTo(10_000L)
        assertThat(state.snapshot.cachedRanges.first().endMs).isEqualTo(60_000L)
    }

    /**
     * WebView 暂停事件必须保留最新进度并切换到暂停态。
     */
    @Test
    fun playback_event_updates_engine_state_to_paused() = runTest {
        val engine = createEngine(WebViewPlayerCommandBus())
        engine.load(sampleRequest())

        engine.updateFromWebView(
            WebViewPlaybackEvent(
                positionMs = 18_000L,
                durationMs = 90_000L,
                isPlaying = false,
            ),
        )

        val state = engine.state.value as PlayerState.Paused
        assertThat(state.snapshot?.positionMs).isEqualTo(18_000L)
        assertThat(state.snapshot?.durationMs).isEqualTo(90_000L)
    }

    /**
     * 收集 WebView 命令。
     *
     * @return 已收集命令列表。
     */
    private fun WebViewPlayerCommandBus.recordCommands(
        scope: TestScope,
    ): MutableList<WebViewPlayerCommand> {
        val commands = mutableListOf<WebViewPlayerCommand>()
        scope.backgroundScope.launch(UnconfinedTestDispatcher(scope.testScheduler)) {
            this@recordCommands.commands.collect { command ->
                commands += command
            }
        }
        return commands
    }

    /**
     * 创建测试内核。
     *
     * @param commandBus 播放命令总线。
     * @return WebView 播放内核。
     */
    private fun createEngine(commandBus: WebViewPlayerCommandBus): WebViewPlayerEngine {
        val dispatcher = UnconfinedTestDispatcher()
        return WebViewPlayerEngine(
            dispatchers = TestDispatcherProvider(dispatcher),
            commandBus = commandBus,
        )
    }

    /**
     * 构造测试播放请求。
     *
     * @return 播放请求。
     */
    private fun sampleRequest(): PlaybackRequest {
        return PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-1",
            url = "https://example.com/video.m3u8",
            startPositionMs = 0L,
        )
    }
}

/**
 * 测试协程调度器。
 *
 * @property dispatcher 所有分层共享的测试调度器。
 */
private class TestDispatcherProvider(
    private val dispatcher: CoroutineDispatcher,
) : DispatcherProvider {
    /** 主线程调度器。 */
    override val main: CoroutineDispatcher = dispatcher

    /** 播放调度器。 */
    override val playback: CoroutineDispatcher = dispatcher

    /** IO 调度器。 */
    override val io: CoroutineDispatcher = dispatcher

    /** 默认调度器。 */
    override val default: CoroutineDispatcher = dispatcher
}
