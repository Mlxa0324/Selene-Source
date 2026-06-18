package org.moontechlab.selene.tv.feature.detail

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoSource

/**
 * 校验 TV 详情页状态机契约。
 *
 * 这些用例对齐 Flutter TV 详情页的“双路加载、增量首播、续播目标等待、完成空态”逻辑。
 */
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
        val sourceId = "$source::$videoId"
        return TvVideoSource(
            id = sourceId,
            source = source,
            videoId = videoId,
            name = "线路 $source",
            episodes = List(episodeCount) { index ->
                TvEpisode(
                    id = "$sourceId-$index",
                    title = "第 ${index + 1} 集",
                    url = "https://cdn.test/$source/$videoId/${index + 1}.m3u8",
                )
            },
        )
    }
}
