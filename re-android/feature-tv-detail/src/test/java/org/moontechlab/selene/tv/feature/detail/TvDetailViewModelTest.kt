package org.moontechlab.selene.tv.feature.detail

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.data.model.TvVideoSource
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest
import org.moontechlab.selene.tv.core.player.api.PlaybackSnapshot
import org.moontechlab.selene.tv.core.player.api.PlayerEngine
import org.moontechlab.selene.tv.core.player.api.PlayerState
import org.moontechlab.selene.tv.core.player.api.TvResizeMode

/**
 * 校验 TV 详情页状态机契约。
 *
 * 这些用例对齐 Flutter TV 详情页的“双路加载、增量首播、续播目标等待、完成空态”逻辑。
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TvDetailViewModelTest {
    /**
     * 精确源先返回可播线路时，应立即生成播放请求，并在补源完成后追加线路。
     */
    @Test
    fun load_selects_exact_source_immediately_and_appends_more_sources() = runTest {
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ ->
                listOf(playableSource(source = "source-b", videoId = "search-video", episodeCount = 2))
            },
        )

        viewModel.load(defaultEntry())

        val state = viewModel.state.value
        assertThat(state.errorMessage).isNull()
        assertThat(state.initialSourcesLoaded).isTrue()
        assertThat(state.moreSourcesLoaded).isTrue()
        assertThat(state.emptyPlaybackCompleted).isFalse()
        assertThat(state.currentSourceId).isEqualTo("source-a::exact-video")
        assertThat(state.playbackRequest?.url).isEqualTo("https://cdn.test/source-a/exact-video/1.m3u8")
        assertThat(state.detail?.sources?.map { source -> source.id })
            .containsExactly("source-a::exact-video", "source-b::search-video")
            .inOrder()
    }

    /**
     * 标题补源先返回可播线路时，应立即起播，不能等精确源结束。
     */
    @Test
    fun load_selects_more_source_when_it_arrives_before_exact_source() = runTest {
        val exactGate = CompletableDeferred<Unit>()
        val incrementalDelivered = CompletableDeferred<Unit>()
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                exactGate.await()
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, onIncremental ->
                onIncremental(listOf(playableSource(source = "source-b", videoId = "search-video", episodeCount = 1)))
                incrementalDelivered.complete(Unit)
                emptyList()
            },
        )

        val loadJob = launch { viewModel.load(defaultEntry()) }
        incrementalDelivered.await()

        val incrementalState = viewModel.state.value
        assertThat(incrementalState.currentSourceId).isEqualTo("source-b::search-video")
        assertThat(incrementalState.playbackRequest?.url).isEqualTo("https://cdn.test/source-b/search-video/1.m3u8")
        assertThat(incrementalState.isInitialLoading).isFalse()
        assertThat(incrementalState.moreSourcesLoaded).isFalse()

        exactGate.complete(Unit)
        loadJob.join()

        assertThat(viewModel.state.value.detail?.sources?.map { source -> source.id })
            .containsExactly("source-b::search-video", "source-a::exact-video")
            .inOrder()
        assertThat(viewModel.state.value.currentSourceId).isEqualTo("source-b::search-video")
    }

    /**
     * 精确源失败不能进入错误态；标题补源成功后仍要正常播放。
     */
    @Test
    fun load_uses_more_sources_when_exact_source_fails() = runTest {
        val viewModel = TvDetailViewModel(
            loadExactSources = { error("详情接口失败") },
            loadMoreSources = { _, _ ->
                listOf(playableSource(source = "source-b", videoId = "search-video", episodeCount = 1))
            },
        )

        viewModel.load(defaultEntry())

        val state = viewModel.state.value
        assertThat(state.errorMessage).isNull()
        assertThat(state.initialSourcesLoaded).isTrue()
        assertThat(state.moreSourcesLoaded).isTrue()
        assertThat(state.currentSourceId).isEqualTo("source-b::search-video")
        assertThat(state.playbackRequest?.url).isEqualTo("https://cdn.test/source-b/search-video/1.m3u8")
    }

    /**
     * 有续播目标时，非目标源先到也不能抢播；目标源命中后再按续播集数和秒数起播。
     */
    @Test
    fun load_waits_for_resume_target_before_initial_playback() = runTest {
        val targetGate = CompletableDeferred<Unit>()
        val nonTargetDelivered = CompletableDeferred<Unit>()
        val viewModel = TvDetailViewModel(
            loadExactSources = { emptyList() },
            loadMoreSources = { _, onIncremental ->
                onIncremental(listOf(playableSource(source = "source-b", videoId = "wrong-video", episodeCount = 2)))
                nonTargetDelivered.complete(Unit)
                targetGate.await()
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 3))
            },
            loadResumeRecord = {
                TvDetailResumeRecord(
                    source = "source-a",
                    videoId = "exact-video",
                    episodeIndex = 1,
                    positionMs = 45_000L,
                    sourceName = "线路 source-a",
                )
            },
        )

        val loadJob = launch { viewModel.load(defaultEntry()) }
        nonTargetDelivered.await()

        val waitingState = viewModel.state.value
        assertThat(waitingState.detail?.sources?.map { source -> source.id })
            .containsExactly("source-b::wrong-video")
        assertThat(waitingState.currentSourceId).isEmpty()
        assertThat(waitingState.playbackRequest).isNull()
        assertThat(waitingState.isInitialLoading).isTrue()

        targetGate.complete(Unit)
        loadJob.join()

        val state = viewModel.state.value
        assertThat(state.currentSourceId).isEqualTo("source-a::exact-video")
        assertThat(state.currentEpisodeId).isEqualTo("source-a::exact-video-1")
        assertThat(state.playbackRequest?.startPositionMs).isEqualTo(45_000L)
        assertThat(state.playbackRequest?.episodeIndex).isEqualTo(1)
    }

    /**
     * 续播记录读取不能阻塞精确源和标题补源请求启动。
     */
    @Test
    fun load_starts_source_loaders_before_resume_record_finishes() = runTest {
        val resumeGate = CompletableDeferred<TvDetailResumeRecord?>()
        val exactStarted = CompletableDeferred<Unit>()
        val moreStarted = CompletableDeferred<Unit>()
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                exactStarted.complete(Unit)
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ ->
                moreStarted.complete(Unit)
                emptyList()
            },
            loadResumeRecord = { resumeGate.await() },
        )

        val loadJob = launch { viewModel.load(defaultEntry()) }
        exactStarted.await()
        moreStarted.await()

        assertThat(viewModel.state.value.currentSourceId).isEmpty()
        assertThat(viewModel.state.value.playbackRequest).isNull()

        resumeGate.complete(null)
        loadJob.join()

        assertThat(viewModel.state.value.currentSourceId).isEqualTo("source-a::exact-video")
    }

    /**
     * 搜索全部完成仍然没有可播线路时，应进入正式完成空态。
     */
    @Test
    fun load_marks_completed_empty_state_when_all_source_loaders_return_empty() = runTest {
        val viewModel = TvDetailViewModel(
            loadExactSources = { emptyList() },
            loadMoreSources = { _, _ -> emptyList() },
        )

        viewModel.load(defaultEntry())

        val state = viewModel.state.value
        assertThat(state.errorMessage).isNull()
        assertThat(state.initialSourcesLoaded).isTrue()
        assertThat(state.moreSourcesLoaded).isTrue()
        assertThat(state.isInitialLoading).isFalse()
        assertThat(state.emptyPlaybackCompleted).isTrue()
        assertThat(state.playbackRequest).isNull()
    }

    /**
     * 脏线路即使携带空剧集列表，也不能把详情页切进黑色真实播放器容器。
     */
    @Test
    fun load_treats_blank_episode_urls_as_unplayable_sources() = runTest {
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(
                    sourceWithEpisodeUrls(
                        source = "source-a",
                        videoId = "exact-video",
                        episodeUrls = listOf("", "   "),
                    ),
                )
            },
            loadMoreSources = { _, _ -> emptyList() },
        )

        viewModel.load(defaultEntry())

        val state = viewModel.state.value
        assertThat(state.currentSourceId).isEmpty()
        assertThat(state.previewPlaybackStarted).isFalse()
        assertThat(state.previewIsLoading).isFalse()
        assertThat(state.playbackRequest).isNull()
        assertThat(state.emptyPlaybackCompleted).isTrue()
    }

    /**
     * 同一 source + id 重复返回时，应保留剧集更完整的线路。
     */
    @Test
    fun load_replaces_duplicate_source_with_more_complete_episode_list() = runTest {
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ ->
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 3))
            },
        )

        viewModel.load(defaultEntry())

        val state = viewModel.state.value
        assertThat(state.detail?.sources).hasSize(1)
        assertThat(state.currentSourceId).isEqualTo("source-a::exact-video")
        assertThat(state.currentEpisodeId).isEqualTo("source-a::exact-video-0")
        assertThat(state.currentSource?.episodes?.map { episode -> episode.id })
            .containsExactly(
                "source-a::exact-video-0",
                "source-a::exact-video-1",
                "source-a::exact-video-2",
            )
            .inOrder()
    }

    /**
     * 切集后播放器请求应刷新为新剧集。
     */
    @Test
    fun selectEpisode_updates_playback_request() = runTest {
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 2))
            },
        )
        viewModel.load(defaultEntry())

        viewModel.selectEpisode("source-a::exact-video-1")

        val request = viewModel.state.value.playbackRequest
        assertThat(request?.episodeId).isEqualTo("source-a::exact-video-1")
        assertThat(request?.episodeIndex).isEqualTo(1)
        assertThat(request?.url).isEqualTo("https://cdn.test/source-a/exact-video/2.m3u8")
    }

    /**
     * 预览播放器 load 同步失败时，必须结束 loading，避免详情头部一直转圈。
     */
    @Test
    fun load_stops_preview_loading_when_preview_engine_load_fails_immediately() = runTest {
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            playerEngine = FailingPreviewPlayerEngine(
                loadError = IllegalStateException("预览源加载失败"),
            ),
            previewDispatcher = StandardTestDispatcher(testScheduler),
        )

        viewModel.load(defaultEntry())
        advanceUntilIdle()

        val state = viewModel.state.value
        assertThat(state.previewPlaybackStarted).isTrue()
        assertThat(state.previewIsLoading).isFalse()
        assertThat(state.currentSourceId).isEqualTo("source-a::exact-video")
        assertThat(state.playbackRequest?.url).isEqualTo("https://cdn.test/source-a/exact-video/1.m3u8")
    }

    /**
     * 预览播放器异步上报错误时，也必须结束 loading，避免一直显示加载遮罩。
     */
    @Test
    fun load_stops_preview_loading_when_preview_engine_reports_error_state() = runTest {
        val previewEngine = FailingPreviewPlayerEngine()
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            playerEngine = previewEngine,
            previewDispatcher = StandardTestDispatcher(testScheduler),
        )

        viewModel.load(defaultEntry())
        advanceUntilIdle()
        previewEngine.emitState(PlayerState.Error(message = "异步预览失败"))
        advanceUntilIdle()

        val state = viewModel.state.value
        assertThat(state.previewPlaybackStarted).isTrue()
        assertThat(state.previewIsLoading).isFalse()
        assertThat(state.previewIsPlaying).isFalse()
    }

    /**
     * 共享播放器会话已经持有同一媒体时，详情页预览不能重复触发一次 load。
     */
    @Test
    fun load_skips_preview_reload_when_engine_already_has_same_media() = runTest {
        val previewEngine = FailingPreviewPlayerEngine()
        previewEngine.emitState(
            PlayerState.Paused(
                snapshot = PlaybackRequest(
                    videoId = "exact-video",
                    videoTitle = "测试影片",
                    sourceId = "source-a",
                    episodeId = "source-a::exact-video-0",
                    episodeIndex = 0,
                    episodeTitle = "第 1 集",
                    url = "https://cdn.test/source-a/exact-video/1.m3u8",
                    startPositionMs = 24_000L,
                ).toSnapshot(positionMs = 41_000L),
            ),
        )
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            playerEngine = previewEngine,
            previewDispatcher = StandardTestDispatcher(testScheduler),
        )

        viewModel.load(defaultEntry())
        advanceUntilIdle()

        val state = viewModel.state.value
        assertThat(previewEngine.loadCalls).isEqualTo(0)
        assertThat(state.previewPlaybackStarted).isTrue()
        assertThat(state.previewIsLoading).isFalse()
        assertThat(state.previewPositionMs).isEqualTo(41_000L)
    }

    /**
     * 详情页切到全屏再返回时，后台加载任务不能因为重复进入页面而再发起一轮。
     */
    @Test
    fun ensureLoaded_does_not_restart_same_detail_load_when_job_is_active_or_finished() = runTest {
        val exactGate = CompletableDeferred<Unit>()
        var exactLoadCalls = 0
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                exactLoadCalls += 1
                exactGate.await()
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            previewDispatcher = StandardTestDispatcher(testScheduler),
        )

        viewModel.ensureLoaded("exact-video")
        advanceUntilIdle()
        viewModel.ensureLoaded("exact-video")

        assertThat(exactLoadCalls).isEqualTo(1)

        exactGate.complete(Unit)
        advanceUntilIdle()
        viewModel.ensureLoaded("exact-video")
        advanceUntilIdle()

        assertThat(exactLoadCalls).isEqualTo(1)
    }

    /**
     * 标题补源未结束时，匹配的真实播放态仍应在两秒后独立加载推荐且只启动一次。
     */
    @Test
    fun recommends_loads_after_matching_playing_delay_without_waiting_for_more_sources() = runTest {
        val moreGate = CompletableDeferred<Unit>()
        val previewEngine = FailingPreviewPlayerEngine()
        val diagnostics = mutableListOf<TvDetailRecommendDiagnostic>()
        var recommendCalls = 0
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ ->
                moreGate.await()
                emptyList()
            },
            loadRecommends = { _, _ ->
                recommendCalls += 1
                listOf(recommendCard("recommend-1"))
            },
            playerEngine = previewEngine,
            previewDispatcher = StandardTestDispatcher(testScheduler),
            recommendDiagnosticSink = TvDetailRecommendDiagnosticSink { event -> diagnostics += event },
        )

        val loadJob = launch { viewModel.load(defaultEntry()) }
        runCurrent()
        val request = requireNotNull(viewModel.state.value.playbackRequest)

        previewEngine.emitState(PlayerState.Playing(request.toSnapshot(positionMs = 1_000L)))
        runCurrent()
        previewEngine.emitState(PlayerState.Playing(request.toSnapshot(positionMs = 2_000L)))
        runCurrent()

        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Scheduled)
        advanceTimeBy(1_999L)
        runCurrent()
        assertThat(recommendCalls).isEqualTo(0)

        advanceTimeBy(1L)
        runCurrent()

        assertThat(recommendCalls).isEqualTo(1)
        assertThat(viewModel.state.value.recommendCards).containsExactly(recommendCard("recommend-1"))
        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Loaded)
        assertThat(moreGate.isCompleted).isFalse()
        assertThat(diagnostics.map { event -> event.stage })
            .containsExactly(
                TvDetailRecommendDiagnosticStage.Scheduled,
                TvDetailRecommendDiagnosticStage.Loading,
                TvDetailRecommendDiagnosticStage.Success,
            )
            .inOrder()

        moreGate.complete(Unit)
        runCurrent()
        loadJob.join()
    }

    /**
     * 共享会话或旧媒体的播放快照不匹配当前请求时，不能启动当前详情推荐。
     */
    @Test
    fun recommends_ignores_playing_snapshot_for_different_media() = runTest {
        val previewEngine = FailingPreviewPlayerEngine()
        var recommendCalls = 0
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            loadRecommends = { _, _ ->
                recommendCalls += 1
                listOf(recommendCard("unexpected"))
            },
            playerEngine = previewEngine,
            previewDispatcher = StandardTestDispatcher(testScheduler),
        )

        viewModel.load(defaultEntry())
        runCurrent()
        val stateBeforeWrongSnapshot = viewModel.state.value
        val wrongRequest = requireNotNull(viewModel.state.value.playbackRequest).copy(
            videoId = "shared-session-video",
            episodeId = "shared-session-episode",
            url = "https://cdn.test/shared/session.m3u8",
        )
        val wrongSnapshot = wrongRequest.toSnapshot(positionMs = 88_000L).copy(
            durationMs = 999_000L,
            networkSpeedBytesPerSecond = 7_777L,
        )

        previewEngine.emitState(PlayerState.Playing(wrongSnapshot))
        runCurrent()
        advanceTimeBy(2_000L)
        runCurrent()

        assertThat(recommendCalls).isEqualTo(0)
        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Idle)
        assertThat(viewModel.state.value.previewPlayerReady)
            .isEqualTo(stateBeforeWrongSnapshot.previewPlayerReady)
        assertThat(viewModel.state.value.previewIsPlaying)
            .isEqualTo(stateBeforeWrongSnapshot.previewIsPlaying)
        assertThat(viewModel.state.value.previewPositionMs)
            .isEqualTo(stateBeforeWrongSnapshot.previewPositionMs)
        assertThat(viewModel.state.value.previewDurationMs)
            .isEqualTo(stateBeforeWrongSnapshot.previewDurationMs)
        assertThat(viewModel.state.value.previewNetworkSpeed)
            .isEqualTo(stateBeforeWrongSnapshot.previewNetworkSpeed)
        assertThat(viewModel.state.value.playbackRequest?.startPositionMs)
            .isEqualTo(stateBeforeWrongSnapshot.playbackRequest?.startPositionMs)
    }

    /**
     * 切集取消旧播放器 load 时，取消异常不能被当成真实加载失败并触发推荐兜底。
     */
    @Test
    fun recommends_does_not_fallback_when_previous_player_load_is_cancelled_by_episode_switch() = runTest {
        val previewEngine = SuspendingFirstLoadPlayerEngine()
        val diagnostics = mutableListOf<TvDetailRecommendDiagnostic>()
        var recommendCalls = 0
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 2))
            },
            loadMoreSources = { _, _ -> emptyList() },
            loadRecommends = { _, _ ->
                recommendCalls += 1
                emptyList()
            },
            playerEngine = previewEngine,
            previewDispatcher = StandardTestDispatcher(testScheduler),
            recommendDiagnosticSink = TvDetailRecommendDiagnosticSink { event -> diagnostics += event },
        )

        viewModel.load(defaultEntry())
        runCurrent()
        assertThat(previewEngine.firstLoadStarted.isCompleted).isTrue()

        viewModel.selectEpisode("source-a::exact-video-1")
        runCurrent()

        assertThat(previewEngine.firstLoadCancelled).isTrue()
        assertThat(previewEngine.loadedRequests.map { request -> request.episodeId })
            .containsExactly("source-a::exact-video-0", "source-a::exact-video-1")
            .inOrder()
        assertThat(recommendCalls).isEqualTo(0)
        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Idle)
        assertThat(diagnostics.any { event ->
            event.stage == TvDetailRecommendDiagnosticStage.Failure ||
                event.trigger == "player-load-failure"
        }).isFalse()
    }

    /**
     * 双路完成且没有可播源时，应立即执行一次推荐兜底并记录空结果。
     */
    @Test
    fun recommends_falls_back_once_when_source_lanes_finish_empty() = runTest {
        val diagnostics = mutableListOf<TvDetailRecommendDiagnostic>()
        var recommendCalls = 0
        val viewModel = TvDetailViewModel(
            loadExactSources = { emptyList() },
            loadMoreSources = { _, _ -> emptyList() },
            loadRecommends = { _, _ ->
                recommendCalls += 1
                emptyList()
            },
            previewDispatcher = StandardTestDispatcher(testScheduler),
            recommendDiagnosticSink = TvDetailRecommendDiagnosticSink { event -> diagnostics += event },
        )

        viewModel.load(defaultEntry())
        runCurrent()

        assertThat(recommendCalls).isEqualTo(1)
        assertThat(viewModel.state.value.emptyPlaybackCompleted).isTrue()
        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Empty)
        assertThat(diagnostics.map { event -> event.stage })
            .containsExactly(
                TvDetailRecommendDiagnosticStage.Scheduled,
                TvDetailRecommendDiagnosticStage.Loading,
                TvDetailRecommendDiagnosticStage.Empty,
            )
            .inOrder()
    }

    /**
     * 已选出有效播放请求但没有播放器内核时，应立即执行一次推荐兜底。
     */
    @Test
    fun recommends_falls_back_once_when_player_engine_is_absent() = runTest {
        var recommendCalls = 0
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            loadRecommends = { _, _ ->
                recommendCalls += 1
                listOf(recommendCard("recommend-null-engine"))
            },
            playerEngine = null,
            previewDispatcher = StandardTestDispatcher(testScheduler),
        )

        viewModel.load(defaultEntry())
        runCurrent()

        assertThat(recommendCalls).isEqualTo(1)
        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Loaded)
    }

    /**
     * 播放器加载请求立即失败时，应结束预览 loading 并执行一次推荐兜底。
     */
    @Test
    fun recommends_falls_back_once_when_player_load_fails() = runTest {
        var recommendCalls = 0
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            loadRecommends = { _, _ ->
                recommendCalls += 1
                listOf(recommendCard("recommend-load-failure"))
            },
            playerEngine = FailingPreviewPlayerEngine(
                loadError = IllegalStateException("预览源加载失败"),
            ),
            previewDispatcher = StandardTestDispatcher(testScheduler),
        )

        viewModel.load(defaultEntry())
        runCurrent()

        assertThat(recommendCalls).isEqualTo(1)
        assertThat(viewModel.state.value.previewIsLoading).isFalse()
        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Loaded)
    }

    /**
     * 当前预览请求收到播放器错误态时，应立即执行一次推荐兜底。
     */
    @Test
    fun recommends_falls_back_once_when_player_reports_error() = runTest {
        val previewEngine = FailingPreviewPlayerEngine()
        var recommendCalls = 0
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            loadRecommends = { _, _ ->
                recommendCalls += 1
                listOf(recommendCard("recommend-player-error"))
            },
            playerEngine = previewEngine,
            previewDispatcher = StandardTestDispatcher(testScheduler),
        )

        viewModel.load(defaultEntry())
        runCurrent()
        previewEngine.emitState(PlayerState.Error(message = "异步预览失败"))
        runCurrent()

        assertThat(recommendCalls).isEqualTo(1)
        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Loaded)
    }

    /**
     * 有效播放器仍处于 Loading 时，即使双路源加载已经完成也不能提前触发推荐。
     */
    @Test
    fun recommends_waits_for_playing_when_valid_engine_remains_loading() = runTest {
        val previewEngine = FailingPreviewPlayerEngine()
        var recommendCalls = 0
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            loadRecommends = { _, _ ->
                recommendCalls += 1
                listOf(recommendCard("unexpected"))
            },
            playerEngine = previewEngine,
            previewDispatcher = StandardTestDispatcher(testScheduler),
        )

        viewModel.load(defaultEntry())
        runCurrent()
        advanceTimeBy(5_000L)
        runCurrent()

        assertThat(previewEngine.state.value).isEqualTo(PlayerState.Loading)
        assertThat(viewModel.state.value.initialSourcesLoaded).isTrue()
        assertThat(viewModel.state.value.moreSourcesLoaded).isTrue()
        assertThat(recommendCalls).isEqualTo(0)
        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Idle)
    }

    /**
     * 推荐加载失败只能更新推荐错误状态，不能清除已经建立的播放请求和线路状态。
     */
    @Test
    fun recommends_failure_preserves_playback_and_source_state() = runTest {
        val previewEngine = FailingPreviewPlayerEngine()
        val diagnostics = mutableListOf<TvDetailRecommendDiagnostic>()
        val viewModel = TvDetailViewModel(
            loadExactSources = {
                listOf(playableSource(source = "source-a", videoId = "exact-video", episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            loadRecommends = { _, _ -> error("推荐请求失败 <html> cookie=secret") },
            playerEngine = previewEngine,
            previewDispatcher = StandardTestDispatcher(testScheduler),
            recommendDiagnosticSink = TvDetailRecommendDiagnosticSink { event -> diagnostics += event },
        )

        viewModel.load(defaultEntry())
        runCurrent()
        val request = requireNotNull(viewModel.state.value.playbackRequest)
        previewEngine.emitState(PlayerState.Playing(request.toSnapshot()))
        runCurrent()
        advanceTimeBy(2_000L)
        runCurrent()

        val state = viewModel.state.value
        assertThat(state.recommendLoadState).isEqualTo(TvDetailRecommendLoadState.Failed)
        assertThat(state.recommendErrorMessage).contains("推荐请求失败")
        assertThat(state.currentSourceId).isEqualTo("source-a::exact-video")
        assertThat(state.playbackRequest).isNotNull()
        assertThat(state.errorMessage).isNull()
        assertThat(diagnostics.map { event -> event.stage })
            .containsExactly(
                TvDetailRecommendDiagnosticStage.Scheduled,
                TvDetailRecommendDiagnosticStage.Loading,
                TvDetailRecommendDiagnosticStage.Failure,
            )
            .inOrder()
        val failureDiagnostic = diagnostics.last { event ->
            event.stage == TvDetailRecommendDiagnosticStage.Failure
        }
        assertThat(failureDiagnostic.message).doesNotContain("<html>")
        assertThat(failureDiagnostic.message).doesNotContain("cookie")
    }

    /**
     * 新详情开始后，旧详情正在执行的推荐结果必须被判定为过期且不能覆盖新状态。
     */
    @Test
    fun recommends_ignores_stale_in_flight_result_after_second_detail_load() = runTest {
        val previewEngine = FailingPreviewPlayerEngine()
        val oldRecommendGate = CompletableDeferred<List<TvVideoCard>>()
        val diagnostics = mutableListOf<TvDetailRecommendDiagnostic>()
        var recommendCalls = 0
        val viewModel = TvDetailViewModel(
            loadExactSources = { entry ->
                listOf(playableSource(source = entry.source, videoId = entry.videoId, episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            loadRecommends = { entry, _ ->
                recommendCalls += 1
                if (entry.videoId == "first-video") {
                    // 忽略任务取消，模拟已进入不可取消网络边界的旧请求晚到。
                    withContext(NonCancellable) { oldRecommendGate.await() }
                } else {
                    listOf(recommendCard("second-recommend"))
                }
            },
            playerEngine = previewEngine,
            previewDispatcher = StandardTestDispatcher(testScheduler),
            recommendDiagnosticSink = TvDetailRecommendDiagnosticSink { event -> diagnostics += event },
        )
        val firstEntry = defaultEntry().copy(videoId = "first-video", title = "第一部影片")
        val secondEntry = defaultEntry().copy(videoId = "second-video", title = "第二部影片")

        viewModel.load(firstEntry)
        runCurrent()
        val firstRequest = requireNotNull(viewModel.state.value.playbackRequest)
        previewEngine.emitState(PlayerState.Playing(firstRequest.toSnapshot()))
        runCurrent()
        advanceTimeBy(2_000L)
        runCurrent()
        assertThat(recommendCalls).isEqualTo(1)

        viewModel.load(secondEntry)
        runCurrent()
        oldRecommendGate.complete(listOf(recommendCard("stale-recommend")))
        runCurrent()

        val state = viewModel.state.value
        assertThat(state.detail?.id).isEqualTo("second-video")
        assertThat(state.recommendCards).isEmpty()
        assertThat(state.recommendLoadState).isEqualTo(TvDetailRecommendLoadState.Idle)
        assertThat(diagnostics.map { event -> event.stage })
            .contains(TvDetailRecommendDiagnosticStage.StaleIgnored)
    }

    /**
     * 推荐仍处于两秒延迟阶段时切换详情，只取消任务，不应误报旧结果被忽略。
     */
    @Test
    fun recommends_does_not_emit_stale_diagnostic_when_delayed_job_is_cancelled_before_loading() = runTest {
        val previewEngine = FailingPreviewPlayerEngine()
        val diagnostics = mutableListOf<TvDetailRecommendDiagnostic>()
        var recommendCalls = 0
        val viewModel = TvDetailViewModel(
            loadExactSources = { entry ->
                listOf(playableSource(source = entry.source, videoId = entry.videoId, episodeCount = 1))
            },
            loadMoreSources = { _, _ -> emptyList() },
            loadRecommends = { _, _ ->
                recommendCalls += 1
                listOf(recommendCard("unexpected"))
            },
            playerEngine = previewEngine,
            previewDispatcher = StandardTestDispatcher(testScheduler),
            recommendDiagnosticSink = TvDetailRecommendDiagnosticSink { event -> diagnostics += event },
        )
        val firstEntry = defaultEntry().copy(videoId = "first-video", title = "第一部影片")
        val secondEntry = defaultEntry().copy(videoId = "second-video", title = "第二部影片")

        viewModel.load(firstEntry)
        runCurrent()
        val firstRequest = requireNotNull(viewModel.state.value.playbackRequest)
        previewEngine.emitState(PlayerState.Playing(firstRequest.toSnapshot()))
        runCurrent()
        assertThat(viewModel.state.value.recommendLoadState)
            .isEqualTo(TvDetailRecommendLoadState.Scheduled)

        viewModel.load(secondEntry)
        runCurrent()
        advanceTimeBy(2_000L)
        runCurrent()

        assertThat(recommendCalls).isEqualTo(0)
        assertThat(diagnostics.map { event -> event.stage })
            .doesNotContain(TvDetailRecommendDiagnosticStage.StaleIgnored)
    }

    /**
     * 构造默认详情入口。
     *
     * @return 测试详情入口。
     */
    private fun defaultEntry(): TvDetailEntry {
        return TvDetailEntry(
            source = "source-a",
            videoId = "exact-video",
            title = "测试影片",
            searchTitle = "测试影片",
            year = "2026",
            posterUrl = "https://img.test/poster.jpg",
        )
    }

    /**
     * 构造可播放线路。
     *
     * @param source 后台来源标识。
     * @param videoId 后台视频 ID。
     * @param episodeCount 剧集数量。
     * @return 可播放线路。
     */
    private fun playableSource(
        source: String,
        videoId: String,
        episodeCount: Int,
    ): TvVideoSource {
        return sourceWithEpisodeUrls(
            source = source,
            videoId = videoId,
            episodeUrls = List(episodeCount) { index ->
                "https://cdn.test/$source/$videoId/${index + 1}.m3u8"
            },
        )
    }

    /**
     * 构造指定播放地址列表的线路。
     *
     * @param source 后台来源标识。
     * @param videoId 后台视频 ID。
     * @param episodeUrls 剧集播放地址列表。
     * @return 指定地址列表的线路。
     */
    private fun sourceWithEpisodeUrls(
        source: String,
        videoId: String,
        episodeUrls: List<String>,
    ): TvVideoSource {
        val sourceId = "$source::$videoId"
        return TvVideoSource(
            id = sourceId,
            source = source,
            videoId = videoId,
            name = "线路 $source",
            episodes = episodeUrls.mapIndexed { index, url ->
                TvEpisode(
                    id = "$sourceId-$index",
                    title = "第 ${index + 1} 集",
                    url = url,
                )
            },
        )
    }

    /**
     * 构造推荐卡片。
     *
     * @param id 豆瓣条目 ID。
     * @return 推荐卡片。
     */
    private fun recommendCard(id: String): TvVideoCard {
        return TvVideoCard(
            id = id,
            source = "douban",
            title = "推荐 $id",
            posterUrl = "https://img.test/$id.jpg",
            doubanRate = "9.0",
        )
    }
}

/**
 * 详情页预览播放器失败测试替身。
 */
private class FailingPreviewPlayerEngine(
    private val loadError: Throwable? = null,
) : PlayerEngine {
    /** 当前播放器状态。 */
    private val mutableState = MutableStateFlow<PlayerState>(PlayerState.Idle)

    /** 对外状态流。 */
    override val state: StateFlow<PlayerState> = mutableState

    /** 最近一次加载请求。 */
    var loadedRequest: PlaybackRequest? = null

    /** load 调用次数。 */
    var loadCalls: Int = 0

    /**
     * 模拟预览播放器加载。
     *
     * @param request 播放请求。
     */
    override suspend fun load(request: PlaybackRequest) {
        loadCalls += 1
        loadedRequest = request
        loadError?.let { error -> throw error }
        mutableState.value = PlayerState.Loading
    }

    /** 播放测试空实现。 */
    override suspend fun play() = Unit

    /** 暂停测试空实现。 */
    override suspend fun pause() = Unit

    /** seek 测试空实现。 */
    override suspend fun seekTo(positionMs: Long) = Unit

    /** 倍速测试空实现。 */
    override suspend fun setPlaybackSpeed(speed: Float) = Unit

    /** 比例测试空实现。 */
    override suspend fun setResizeMode(resizeMode: TvResizeMode) = Unit

    /** 快照测试空实现。 */
    override suspend fun captureSnapshot(): PlaybackSnapshot {
        val request = loadedRequest ?: error("测试未加载播放请求")
        return PlaybackSnapshot(
            videoId = request.videoId,
            sourceId = request.sourceId,
            episodeId = request.episodeId,
            url = request.url,
            positionMs = request.startPositionMs,
            durationMs = 0L,
            playbackSpeed = request.playbackSpeed,
            resizeMode = request.resizeMode,
        )
    }

    /** 恢复测试空实现。 */
    override suspend fun restoreSnapshot(snapshot: PlaybackSnapshot) = Unit

    /** 释放测试空实现。 */
    override suspend fun release() = Unit

    /**
     * 主动推送播放器状态。
     *
     * @param state 目标状态。
     */
    fun emitState(state: PlayerState) {
        mutableState.value = state
    }
}

/**
 * 首次加载持续挂起、后续加载正常进入 Loading 的播放器测试替身。
 */
private class SuspendingFirstLoadPlayerEngine : PlayerEngine {
    /** 当前播放器状态。 */
    private val mutableState = MutableStateFlow<PlayerState>(PlayerState.Idle)

    /** 对外状态流。 */
    override val state: StateFlow<PlayerState> = mutableState

    /** 首次加载已经开始。 */
    val firstLoadStarted = CompletableDeferred<Unit>()

    /** 首次加载是否收到取消。 */
    var firstLoadCancelled: Boolean = false

    /** 全部播放器加载请求。 */
    val loadedRequests = mutableListOf<PlaybackRequest>()

    /**
     * 首次请求挂起等待取消，第二次请求正常进入 Loading。
     *
     * @param request 播放请求。
     */
    override suspend fun load(request: PlaybackRequest) {
        loadedRequests += request
        mutableState.value = PlayerState.Loading
        if (loadedRequests.size == 1) {
            firstLoadStarted.complete(Unit)
            try {
                awaitCancellation()
            } finally {
                // 切集取消旧任务时记录取消事实，供测试验证异常类型路径。
                firstLoadCancelled = true
            }
        }
    }

    /** 播放测试空实现。 */
    override suspend fun play() = Unit

    /** 暂停测试空实现。 */
    override suspend fun pause() = Unit

    /**
     * seek 测试空实现。
     *
     * @param positionMs 目标播放位置。
     */
    override suspend fun seekTo(positionMs: Long) = Unit

    /**
     * 倍速测试空实现。
     *
     * @param speed 目标播放倍速。
     */
    override suspend fun setPlaybackSpeed(speed: Float) = Unit

    /**
     * 画面比例测试空实现。
     *
     * @param resizeMode 目标画面比例。
     */
    override suspend fun setResizeMode(resizeMode: TvResizeMode) = Unit

    /**
     * 挂起加载替身不提供播放快照。
     *
     * @return 本方法不会返回。
     */
    override suspend fun captureSnapshot(): PlaybackSnapshot {
        error("挂起加载替身没有播放快照")
    }

    /**
     * 恢复快照测试空实现。
     *
     * @param snapshot 播放快照。
     */
    override suspend fun restoreSnapshot(snapshot: PlaybackSnapshot) = Unit

    /** 释放测试空实现。 */
    override suspend fun release() = Unit
}

/**
 * 将播放请求转换为测试快照。
 *
 * @param positionMs 当前模拟播放位置。
 * @return 对应播放快照。
 */
private fun PlaybackRequest.toSnapshot(positionMs: Long = startPositionMs): PlaybackSnapshot {
    return PlaybackSnapshot(
        videoId = videoId,
        sourceId = sourceId,
        episodeId = episodeId,
        url = url,
        positionMs = positionMs,
        durationMs = 0L,
        playbackSpeed = playbackSpeed,
        resizeMode = resizeMode,
    )
}
