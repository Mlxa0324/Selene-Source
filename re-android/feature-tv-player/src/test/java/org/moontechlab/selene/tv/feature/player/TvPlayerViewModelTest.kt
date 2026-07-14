package org.moontechlab.selene.tv.feature.player

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackCachedRange
import org.moontechlab.selene.tv.core.player.api.PlaybackSnapshot
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

/**
 * 校验 TV 播放器 ViewModel 的播放请求状态。
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TvPlayerViewModelTest {
    /**
     * 详情页进入播放器时必须保留完整播放请求，不能只剩视频 ID。
     */
    @Test
    fun initial_state_keeps_playback_request_from_detail() {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8?token=a&b=2",
            startPositionMs = 12_000L,
        )
        val viewModel = TvPlayerViewModel(initialRequest = request)

        assertThat(viewModel.state.value.playbackRequest).isEqualTo(request)
    }

    /**
     * 播放器进入页面后必须把详情页请求下发给播放器内核。
     */
    @Test
    fun loadInitialRequest_sends_request_to_player_engine() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine()
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )

        viewModel.loadInitialRequest()

        assertThat(engine.loadedRequest).isEqualTo(request)
        assertThat(viewModel.state.value.isPlayerLoading).isEqualTo(false)
        assertThat(viewModel.state.value.playerErrorMessage).isNull()
    }

    /**
     * 共享播放器会话已经在播放同一媒体时，全屏页不能重复触发一次 load。
     */
    @Test
    fun loadInitialRequest_skips_reload_when_engine_already_has_same_media() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 18_000L,
        )
        val engine = RecordingPlayerEngine(durationMs = 120_000L)
        engine.emitState(
            PlayerState.Paused(
                snapshot = request.toTestSnapshot(
                    positionMs = 36_000L,
                    durationMs = 120_000L,
                ),
            ),
        )
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )

        viewModel.loadInitialRequest()

        assertThat(engine.loadCalls).isEqualTo(0)
        assertThat(viewModel.state.value.currentPositionMs).isEqualTo(36_000L)
        assertThat(viewModel.state.value.durationMs).isEqualTo(120_000L)
        assertThat(viewModel.state.value.playerErrorMessage).isNull()
    }

    /**
     * 播放器内核加载失败时应留在全屏页并展示错误状态。
     */
    @Test
    fun loadInitialRequest_keeps_error_message_when_engine_fails() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = RecordingPlayerEngine(
                loadError = IllegalStateException("播放地址加载失败"),
            ),
        )

        viewModel.loadInitialRequest()

        assertThat(viewModel.state.value.isPlayerLoading).isEqualTo(false)
        assertThat(viewModel.state.value.playerErrorMessage).isEqualTo("播放地址加载失败")
    }

    /**
     * ViewModel 必须持续观察播放器内核状态，承接 WebView 上报的真实播放进度。
     */
    @Test
    fun observePlayerState_updates_ui_from_engine_state_flow() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine(durationMs = 120_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()
        val observeJob = backgroundScope.launch {
            viewModel.observePlayerState()
        }
        runCurrent()

        engine.emitState(
            PlayerState.Playing(
                snapshot = request.toTestSnapshot(
                    positionMs = 31_000L,
                    durationMs = 120_000L,
                ),
            ),
        )
        runCurrent()

        assertThat(viewModel.state.value.currentPositionMs).isEqualTo(31_000L)
        assertThat(viewModel.state.value.durationMs).isEqualTo(120_000L)
        assertThat(viewModel.state.value.isPlaybackPlaying).isTrue()
        observeJob.cancel()
    }

    /**
     * ViewModel 必须把播放器内核缓存范围同步给底部进度条。
     */
    @Test
    fun observePlayerState_updates_cached_ranges_from_engine_snapshot() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine(durationMs = 120_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()
        val observeJob = backgroundScope.launch {
            viewModel.observePlayerState()
        }
        runCurrent()

        engine.emitState(
            PlayerState.Playing(
                snapshot = request.toTestSnapshot(
                    positionMs = 31_000L,
                    durationMs = 120_000L,
                    cachedRanges = listOf(
                        PlaybackCachedRange(startMs = 30_000L, endMs = 90_000L),
                    ),
                ),
            ),
        )
        runCurrent()

        assertThat(viewModel.state.value.cachedRanges).containsExactly(
            TvPlayerCachedRange(startMs = 30_000L, endMs = 90_000L),
        )
        observeJob.cancel()
    }

    /**
     * 播放器内核上报网速后，界面状态必须同步给 loading 覆盖层展示。
     */
    @Test
    fun observePlayerState_updates_network_speed_from_engine_snapshot() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine(durationMs = 120_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()
        val observeJob = backgroundScope.launch {
            viewModel.observePlayerState()
        }
        runCurrent()

        engine.emitState(
            PlayerState.Playing(
                snapshot = request.toTestSnapshot(
                    positionMs = 31_000L,
                    durationMs = 120_000L,
                    networkSpeedBytesPerSecond = 1_572_864L,
                ),
            ),
        )
        runCurrent()

        assertThat(viewModel.state.value.networkSpeedBytesPerSecond).isEqualTo(1_572_864L)
        observeJob.cancel()
    }

    /**
     * 全屏播放器播放时，应每跨过 10 秒分段保存一次播放进度。
     */
    @Test
    fun observePlayerState_saves_progress_every_ten_seconds() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine(durationMs = 120_000L)
        val savedProgress = mutableListOf<Triple<PlaybackRequest, Long, Long>>()
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
            savePlaybackProgress = { savedRequest, positionMs, durationMs ->
                savedProgress += Triple(savedRequest, positionMs, durationMs)
            },
        )
        viewModel.loadInitialRequest()
        val observeJob = backgroundScope.launch {
            viewModel.observePlayerState()
        }
        runCurrent()

        engine.emitState(PlayerState.Playing(request.toTestSnapshot(positionMs = 9_000L, durationMs = 120_000L)))
        runCurrent()
        engine.emitState(PlayerState.Playing(request.toTestSnapshot(positionMs = 10_000L, durationMs = 120_000L)))
        runCurrent()
        engine.emitState(PlayerState.Playing(request.toTestSnapshot(positionMs = 19_000L, durationMs = 120_000L)))
        runCurrent()
        engine.emitState(PlayerState.Playing(request.toTestSnapshot(positionMs = 20_000L, durationMs = 120_000L)))
        runCurrent()

        assertThat(savedProgress.map { (_, positionMs, _) -> positionMs })
            .containsExactly(10_000L, 20_000L)
            .inOrder()
        observeJob.cancel()
    }

    /**
     * 播放器已加载但暂停时，确认键语义应调用播放。
     */
    @Test
    fun togglePlayPause_plays_when_loaded_player_is_paused() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine()
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()

        viewModel.togglePlayPause()

        assertThat(engine.playCalls).isEqualTo(1)
        assertThat(engine.pauseCalls).isEqualTo(0)
        assertThat(viewModel.state.value.isPlaybackPlaying).isTrue()
    }

    /**
     * 播放器正在播放时，确认键语义应调用暂停。
     */
    @Test
    fun togglePlayPause_pauses_when_player_is_playing() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine()
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()
        viewModel.togglePlayPause()

        viewModel.togglePlayPause()

        assertThat(engine.pauseCalls).isEqualTo(1)
        assertThat(viewModel.state.value.isPlaybackPlaying).isFalse()
    }

    /**
     * 右方向键短按应按 Flutter TV 规则向前 seek 10 秒。
     */
    @Test
    fun seekByDirection_seeks_forward_by_short_press_delta() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 12_000L,
        )
        val engine = RecordingPlayerEngine()
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()

        viewModel.seekByDirection(direction = 1, holdMs = 100)

        assertThat(engine.seekTargets).containsExactly(22_000L)
        assertThat(viewModel.state.value.currentPositionMs).isEqualTo(22_000L)
    }

    /**
     * 快进/快退：按住不展示加载转圈；松手后展示，直到画面就绪（Playing）再消失。
     */
    @Test
    fun seek_gesture_shows_loading_only_after_release_until_playing() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 12_000L,
        )
        val engine = RecordingPlayerEngine(durationMs = 60_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()
        val observeJob = backgroundScope.launch {
            viewModel.observePlayerState()
        }
        runCurrent()

        viewModel.onSeekGestureStarted()
        viewModel.seekByDirection(direction = 1, holdMs = 100)
        // 按住期间即使内核进入 Loading，也不展示中心转圈。
        engine.emitState(PlayerState.Loading)
        runCurrent()
        assertThat(viewModel.state.value.isSeekGestureActive).isTrue()
        assertThat(viewModel.state.value.isSeekOverlayVisible).isTrue()
        assertThat(viewModel.state.value.shouldShowLoadingOverlay()).isFalse()

        // 松手：收起时间提示，进入等画面加载动画。
        viewModel.onSeekGestureReleased()
        assertThat(viewModel.state.value.isSeekGestureActive).isFalse()
        assertThat(viewModel.state.value.isSeekOverlayVisible).isFalse()
        assertThat(viewModel.state.value.isPostSeekLoading).isTrue()
        assertThat(viewModel.state.value.shouldShowLoadingOverlay()).isTrue()

        // 画面起播后转圈消失。
        engine.emitState(
            PlayerState.Playing(
                snapshot = request.toTestSnapshot(positionMs = 22_000L, durationMs = 60_000L),
            ),
        )
        runCurrent()
        assertThat(viewModel.state.value.isPostSeekLoading).isFalse()
        assertThat(viewModel.state.value.shouldShowLoadingOverlay()).isFalse()
        observeJob.cancel()
    }

    /**
     * 左右键 seek 后必须展示中心时间提示，且提示目标不能脱离真实 seek 目标。
     */
    @Test
    fun seekByDirection_shows_center_overlay_with_real_seek_target() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 12_000L,
        )
        val engine = RecordingPlayerEngine(durationMs = 60_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()

        viewModel.seekByDirection(direction = 1, holdMs = 100)

        assertThat(viewModel.state.value.isSeekOverlayVisible).isTrue()
        assertThat(viewModel.state.value.seekOverlayDirection).isEqualTo(1)
        assertThat(viewModel.state.value.seekOverlayPositionMs).isEqualTo(22_000L)
        assertThat(viewModel.state.value.seekOverlayDisplayPositionMs).isEqualTo(22_000L)
        assertThat(viewModel.state.value.seekOverlayDurationMs).isEqualTo(60_000L)
    }

    /**
     * 长按 seek 的中心提示应使用 Flutter TV 的可读展示时间，不得反向影响真实 seek 目标。
     */
    @Test
    fun seekByDirection_long_press_uses_readable_display_position_without_changing_seek_target() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 12_000L,
        )
        val engine = RecordingPlayerEngine(durationMs = 120_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()

        viewModel.seekByDirection(direction = 1, holdMs = 1_250L)

        assertThat(engine.seekTargets).containsExactly(24_000L)
        assertThat(viewModel.state.value.seekOverlayPositionMs).isEqualTo(24_000L)
        assertThat(viewModel.state.value.seekOverlayDisplayPositionMs).isEqualTo(23_000L)
    }

    /**
     * 左方向键短按应向后 seek，且不能小于 0。
     */
    @Test
    fun seekByDirection_clamps_backward_seek_to_zero() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 6_000L,
        )
        val engine = RecordingPlayerEngine()
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()

        viewModel.seekByDirection(direction = -1, holdMs = 100)

        assertThat(engine.seekTargets).containsExactly(0L)
        assertThat(viewModel.state.value.currentPositionMs).isEqualTo(0L)
    }

    /**
     * 返回键在底部菜单打开时必须只关闭菜单，保留当前菜单选中项。
     */
    @Test
    fun closeMenu_hides_menu_and_keeps_selected_menu() {
        val viewModel = TvPlayerViewModel()
        viewModel.openMenu(PLAYER_MENU_OTHER)

        viewModel.closeMenu()

        assertThat(viewModel.state.value.isMenuVisible).isFalse()
        assertThat(viewModel.state.value.selectedTopMenu).isEqualTo(PLAYER_MENU_OTHER)
    }

    /**
     * 打开底部菜单时必须隐藏 seek 提示，避免两个操作层互相遮挡。
     */
    @Test
    fun openMenu_hides_seek_overlay() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 12_000L,
        )
        val engine = RecordingPlayerEngine()
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()
        viewModel.seekByDirection(direction = 1, holdMs = 100)

        viewModel.openMenu(PLAYER_MENU_PLAYLIST)

        assertThat(viewModel.state.value.isSeekOverlayVisible).isFalse()
        assertThat(viewModel.state.value.isMenuVisible).isTrue()
    }

    /**
     * 倍速菜单确认后必须即时更新 UI 状态和播放器内核。
     */
    @Test
    fun selectPlaybackSpeed_updates_state_and_player_engine() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine()
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()

        viewModel.selectPlaybackSpeed(1.5f)

        assertThat(engine.playbackSpeedChanges).containsExactly(1.5f)
        assertThat(viewModel.state.value.playbackRequest?.playbackSpeed).isEqualTo(1.5f)
        assertThat(viewModel.state.value.selectedPlaybackSpeed).isEqualTo(1.5f)
    }

    /**
     * 画面比例菜单确认后必须即时更新 UI 状态和播放器内核。
     */
    @Test
    fun selectResizeMode_updates_state_and_player_engine() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine()
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()

        viewModel.selectResizeMode(TvResizeMode.FILL)

        assertThat(engine.resizeModeChanges).containsExactly(TvResizeMode.FILL)
        assertThat(viewModel.state.value.playbackRequest?.resizeMode).isEqualTo(TvResizeMode.FILL)
        assertThat(viewModel.state.value.selectedResizeMode).isEqualTo(TvResizeMode.FILL)
    }

    /**
     * 片头菜单确认后必须保存当前播放秒数，和 Flutter TV 的片头跳过设置一致。
     */
    @Test
    fun setSkipIntroToCurrentPosition_saves_current_position_seconds() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 35_500L,
        )
        val engine = RecordingPlayerEngine(durationMs = 120_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()

        viewModel.setSkipIntroToCurrentPosition()

        assertThat(viewModel.state.value.skipIntroSeconds).isEqualTo(35)
    }

    /**
     * 片尾菜单确认后必须保存距离结尾剩余秒数，复用 Flutter TV 的业务语义。
     */
    @Test
    fun setSkipOutroToCurrentPosition_saves_remaining_seconds() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 90_500L,
        )
        val engine = RecordingPlayerEngine(durationMs = 120_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()

        viewModel.setSkipOutroToCurrentPosition()

        assertThat(viewModel.state.value.skipOutroSeconds).isEqualTo(29)
    }

    /**
     * 片头片尾菜单长按必须清空对应配置，避免误设置后只能重启恢复。
     */
    @Test
    fun clearSkipPositions_resets_intro_and_outro_seconds() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 45_000L,
        )
        val engine = RecordingPlayerEngine(durationMs = 120_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
        )
        viewModel.loadInitialRequest()
        viewModel.setSkipIntroToCurrentPosition()
        viewModel.setSkipOutroToCurrentPosition()

        viewModel.clearSkipIntroPosition()
        viewModel.clearSkipOutroPosition()

        assertThat(viewModel.state.value.skipIntroSeconds).isEqualTo(0)
        assertThat(viewModel.state.value.skipOutroSeconds).isEqualTo(0)
    }

    /**
     * 播放器进入页面后必须读取已保存的片头片尾秒数，保持和 Flutter TV 全屏页一致。
     */
    @Test
    fun loadSkipDurations_reads_saved_intro_and_outro_seconds() = runTest {
        val viewModel = TvPlayerViewModel(
            loadSkipIntroSeconds = { 18 },
            loadSkipOutroSeconds = { 24 },
        )

        viewModel.loadSkipDurations()

        assertThat(viewModel.state.value.skipIntroSeconds).isEqualTo(18)
        assertThat(viewModel.state.value.skipOutroSeconds).isEqualTo(24)
    }

    /**
     * 片头菜单确认后必须同步保存秒数，避免退出播放器后配置丢失。
     */
    @Test
    fun setSkipIntroToCurrentPosition_persists_seconds() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 35_500L,
        )
        var savedIntroSeconds: Int? = null
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = RecordingPlayerEngine(durationMs = 120_000L),
            saveSkipIntroSeconds = { seconds -> savedIntroSeconds = seconds },
        )
        viewModel.loadInitialRequest()

        viewModel.setSkipIntroToCurrentPosition()

        assertThat(savedIntroSeconds).isEqualTo(35)
    }

    /**
     * 片尾菜单确认后必须同步保存剩余秒数，和 Flutter TV 的全局配置语义一致。
     */
    @Test
    fun setSkipOutroToCurrentPosition_persists_seconds() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
            startPositionMs = 90_500L,
        )
        var savedOutroSeconds: Int? = null
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = RecordingPlayerEngine(durationMs = 120_000L),
            saveSkipOutroSeconds = { seconds -> savedOutroSeconds = seconds },
        )
        viewModel.loadInitialRequest()

        viewModel.setSkipOutroToCurrentPosition()

        assertThat(savedOutroSeconds).isEqualTo(29)
    }

    /**
     * 长按清空片头片尾时必须同步清空持久化值。
     */
    @Test
    fun clearSkipPositions_persists_zero_seconds() = runTest {
        val savedIntroSeconds = mutableListOf<Int>()
        val savedOutroSeconds = mutableListOf<Int>()
        val viewModel = TvPlayerViewModel(
            saveSkipIntroSeconds = { seconds -> savedIntroSeconds += seconds },
            saveSkipOutroSeconds = { seconds -> savedOutroSeconds += seconds },
        )

        viewModel.clearSkipIntroPosition()
        viewModel.clearSkipOutroPosition()

        assertThat(savedIntroSeconds).containsExactly(0)
        assertThat(savedOutroSeconds).containsExactly(0)
    }

    /**
     * 播放器进入页面后必须按当前播放请求加载对应弹幕评论。
     */
    @Test
    fun loadDanmakuForCurrentRequest_updates_danmaku_state() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            videoTitle = "测试影片",
            sourceId = "source-a",
            episodeId = "ep-2",
            episodeIndex = 1,
            url = "https://cdn.test/video.m3u8",
        )
        var requestedPlaybackRequest: PlaybackRequest? = null
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            loadDanmaku = { playbackRequest ->
                requestedPlaybackRequest = playbackRequest
                TvPlayerDanmakuLoadResult(
                    episodeId = 9002,
                    comments = listOf(
                        TvPlayerDanmakuComment(
                            cid = 12,
                            p = "3.25,5,65280,0",
                            text = "顶部弹幕",
                            timestamp = 1710000001,
                            timeSeconds = 3.25,
                            type = 5,
                            color = 65_280,
                        ),
                    ),
                )
            },
        )

        viewModel.loadDanmakuForCurrentRequest()

        assertThat(requestedPlaybackRequest).isEqualTo(request)
        assertThat(viewModel.state.value.isDanmakuLoading).isFalse()
        assertThat(viewModel.state.value.currentDanmakuEpisodeId).isEqualTo(9002)
        assertThat(viewModel.state.value.danmakuComments.first().text).isEqualTo("顶部弹幕")
        assertThat(viewModel.state.value.danmakuErrorMessage).isNull()
    }

    /**
     * 未匹配到弹幕时应保持播放器可用并清空当前弹幕状态。
     */
    @Test
    fun loadDanmakuForCurrentRequest_clears_state_when_no_match() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            loadDanmaku = { null },
        )

        viewModel.loadDanmakuForCurrentRequest()

        assertThat(viewModel.state.value.isDanmakuLoading).isFalse()
        assertThat(viewModel.state.value.currentDanmakuEpisodeId).isNull()
        assertThat(viewModel.state.value.danmakuComments).isEmpty()
        assertThat(viewModel.state.value.danmakuErrorMessage).isNull()
    }

    /**
     * 关闭弹幕后必须清空当前弹幕态并停止后续发射，复刻 Flutter TV 的清理语义。
     */
    @Test
    fun toggleDanmakuEnabled_off_clears_state_and_stops_emission() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine(durationMs = 60_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
            loadDanmaku = {
                TvPlayerDanmakuLoadResult(
                    episodeId = 9002,
                    comments = listOf(
                        testDanmakuComment(cid = 1, timeSeconds = 1.0, text = "一秒弹幕"),
                    ),
                )
            },
        )
        viewModel.loadInitialRequest()
        viewModel.loadDanmakuForCurrentRequest()
        val observeJob = backgroundScope.launch {
            viewModel.observePlayerState()
        }
        runCurrent()

        viewModel.toggleDanmakuEnabled()
        engine.emitState(
            PlayerState.Playing(
                snapshot = request.toTestSnapshot(
                    positionMs = 1_200L,
                    durationMs = 60_000L,
                ),
            ),
        )
        runCurrent()

        assertThat(viewModel.state.value.isDanmakuEnabled).isFalse()
        assertThat(viewModel.state.value.currentDanmakuEpisodeId).isNull()
        assertThat(viewModel.state.value.danmakuComments).isEmpty()
        assertThat(viewModel.state.value.danmakuEmissionComments).isEmpty()
        observeJob.cancel()
    }

    /**
     * 重新开启弹幕后必须按当前播放请求重新加载弹幕，保持和 Flutter TV 菜单一致。
     */
    @Test
    fun toggleDanmakuEnabled_on_reloads_current_request() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        var loadCalls = 0
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            loadDanmaku = {
                loadCalls += 1
                TvPlayerDanmakuLoadResult(
                    episodeId = 9002,
                    comments = listOf(
                        testDanmakuComment(cid = loadCalls, timeSeconds = 1.0, text = "重新加载"),
                    ),
                )
            },
        )
        viewModel.loadDanmakuForCurrentRequest()
        viewModel.toggleDanmakuEnabled()

        viewModel.toggleDanmakuEnabled()

        assertThat(viewModel.state.value.isDanmakuEnabled).isTrue()
        assertThat(viewModel.state.value.currentDanmakuEpisodeId).isEqualTo(9002)
        assertThat(viewModel.state.value.danmakuComments.map { comment -> comment.text })
            .containsExactly("重新加载")
        assertThat(loadCalls).isEqualTo(2)
    }

    /**
     * 播放进度推进时必须按 Flutter TV 游标规则发射当前时间前的弹幕。
     */
    @Test
    fun observePlayerState_emits_danmaku_comments_by_playback_position() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine(durationMs = 60_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
            loadDanmaku = {
                TvPlayerDanmakuLoadResult(
                    episodeId = 9002,
                    comments = listOf(
                        testDanmakuComment(cid = 1, timeSeconds = 1.0, text = "一秒弹幕"),
                        testDanmakuComment(cid = 2, timeSeconds = 3.25, text = "三秒弹幕"),
                        testDanmakuComment(cid = 3, timeSeconds = 5.0, text = "五秒弹幕"),
                    ),
                )
            },
        )
        viewModel.loadInitialRequest()
        viewModel.loadDanmakuForCurrentRequest()
        val observeJob = backgroundScope.launch {
            viewModel.observePlayerState()
        }
        runCurrent()

        engine.emitState(
            PlayerState.Playing(
                snapshot = request.toTestSnapshot(
                    positionMs = 3_300L,
                    durationMs = 60_000L,
                ),
            ),
        )
        runCurrent()

        assertThat(viewModel.state.value.danmakuEmissionVersion).isEqualTo(1)
        assertThat(viewModel.state.value.danmakuEmissionComments.map { comment -> comment.text })
            .containsExactly("一秒弹幕", "三秒弹幕")
            .inOrder()
        observeJob.cancel()
    }

    /**
     * seek 后必须重置弹幕游标，避免把 seek 前已经过时的弹幕追屏补发。
     */
    @Test
    fun seekByDirection_resets_danmaku_cursor_to_seek_target() = runTest {
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8",
        )
        val engine = RecordingPlayerEngine(durationMs = 60_000L)
        val viewModel = TvPlayerViewModel(
            initialRequest = request,
            playerEngine = engine,
            loadDanmaku = {
                TvPlayerDanmakuLoadResult(
                    episodeId = 9002,
                    comments = listOf(
                        testDanmakuComment(cid = 1, timeSeconds = 3.25, text = "旧位置弹幕"),
                        testDanmakuComment(cid = 2, timeSeconds = 22.0, text = "新位置弹幕"),
                    ),
                )
            },
        )
        viewModel.loadInitialRequest()
        viewModel.loadDanmakuForCurrentRequest()
        val observeJob = backgroundScope.launch {
            viewModel.observePlayerState()
        }
        runCurrent()

        viewModel.seekByDirection(direction = 1, holdMs = 100)
        engine.emitState(
            PlayerState.Playing(
                snapshot = request.toTestSnapshot(
                    positionMs = 10_100L,
                    durationMs = 60_000L,
                ),
            ),
        )
        runCurrent()

        assertThat(viewModel.state.value.danmakuEmissionComments).isEmpty()

        engine.emitState(
            PlayerState.Playing(
                snapshot = request.toTestSnapshot(
                    positionMs = 22_100L,
                    durationMs = 60_000L,
                ),
            ),
        )
        runCurrent()

        assertThat(viewModel.state.value.danmakuEmissionComments.map { comment -> comment.text })
            .containsExactly("新位置弹幕")
        observeJob.cancel()
    }
}

/**
 * 构造测试弹幕评论。
 *
 * @param cid 评论 ID。
 * @param timeSeconds 出现时间，单位秒。
 * @param text 弹幕正文。
 * @return 播放器弹幕评论。
 */
private fun testDanmakuComment(
    cid: Int,
    timeSeconds: Double,
    text: String,
): TvPlayerDanmakuComment {
    return TvPlayerDanmakuComment(
        cid = cid,
        p = "$timeSeconds,1,16777215,0",
        text = text,
        timestamp = 1710000000 + cid,
        timeSeconds = timeSeconds,
        type = 1,
        color = 16_777_215,
    )
}

/**
 * 构造测试播放快照。
 *
 * @param positionMs 当前播放位置。
 * @param durationMs 当前总时长。
 * @return 用于模拟内核状态的播放快照。
 */
private fun PlaybackRequest.toTestSnapshot(
    positionMs: Long,
    durationMs: Long,
    cachedRanges: List<PlaybackCachedRange> = emptyList(),
    networkSpeedBytesPerSecond: Long = 0L,
): PlaybackSnapshot {
    return PlaybackSnapshot(
        videoId = videoId,
        sourceId = sourceId,
        episodeId = episodeId,
        url = url,
        positionMs = positionMs,
        durationMs = durationMs,
        cachedRanges = cachedRanges,
        networkSpeedBytesPerSecond = networkSpeedBytesPerSecond,
        playbackSpeed = playbackSpeed,
        resizeMode = resizeMode,
    )
}

/**
 * 记录播放器内核调用的测试替身。
 */
private class RecordingPlayerEngine(
    private val loadError: Throwable? = null,
    private val durationMs: Long = 0L,
) : PlayerEngine {
    /** load 调用次数。 */
    var loadCalls: Int = 0

    /** 最近一次加载请求。 */
    var loadedRequest: PlaybackRequest? = null

    /** 播放调用次数。 */
    var playCalls: Int = 0

    /** 暂停调用次数。 */
    var pauseCalls: Int = 0

    /** seek 目标记录。 */
    val seekTargets: MutableList<Long> = mutableListOf()

    /** 倍速变更记录。 */
    val playbackSpeedChanges: MutableList<Float> = mutableListOf()

    /** 画面比例变更记录。 */
    val resizeModeChanges: MutableList<TvResizeMode> = mutableListOf()

    /** 内核可变状态。 */
    private val mutableState = MutableStateFlow<PlayerState>(PlayerState.Idle)

    /** 播放器状态。 */
    override val state: StateFlow<PlayerState> = mutableState

    /** 记录加载请求。 */
    override suspend fun load(request: PlaybackRequest) {
        loadCalls += 1
        loadError?.let { error -> throw error }
        loadedRequest = request
        mutableState.value = PlayerState.Paused(snapshot = request.toSnapshot())
    }

    /** 播放测试空实现。 */
    override suspend fun play() {
        playCalls += 1
        mutableState.value = PlayerState.Playing(loadedRequest!!.toSnapshot())
    }

    /** 暂停测试空实现。 */
    override suspend fun pause() {
        pauseCalls += 1
        mutableState.value = PlayerState.Paused(snapshot = loadedRequest?.toSnapshot())
    }

    /** 记录 seek 目标。 */
    override suspend fun seekTo(positionMs: Long) {
        seekTargets += positionMs
        loadedRequest?.let { request ->
            mutableState.value = PlayerState.Paused(
                snapshot = request.toSnapshot(positionMs = positionMs),
            )
        }
    }

    /** 记录倍速变更。 */
    override suspend fun setPlaybackSpeed(speed: Float) {
        playbackSpeedChanges += speed
    }

    /** 记录画面比例变更。 */
    override suspend fun setResizeMode(resizeMode: TvResizeMode) {
        resizeModeChanges += resizeMode
    }

    /** 捕获快照测试空实现。 */
    override suspend fun captureSnapshot(): PlaybackSnapshot {
        error("测试不需要捕获快照")
    }

    /** 恢复快照测试空实现。 */
    override suspend fun restoreSnapshot(snapshot: PlaybackSnapshot) = Unit

    /** 释放测试空实现。 */
    override suspend fun release() = Unit

    /**
     * 主动推送播放器状态。
     *
     * @param playerState 测试要模拟的内核状态。
     */
    fun emitState(playerState: PlayerState) {
        mutableState.value = playerState
    }

    /**
     * 构造测试播放快照。
     *
     * @return 当前请求对应的播放快照。
     */
    private fun PlaybackRequest.toSnapshot(positionMs: Long = startPositionMs): PlaybackSnapshot {
        return PlaybackSnapshot(
            videoId = videoId,
            sourceId = sourceId,
            episodeId = episodeId,
            url = url,
            positionMs = positionMs,
            durationMs = durationMs,
            playbackSpeed = playbackSpeed,
            resizeMode = resizeMode,
        )
    }
}
