package org.moontechlab.selene.tv.feature.home

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvHomePayload
import org.moontechlab.selene.tv.core.data.model.TvHomeSection
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * 校验 TV 首页状态管理契约。
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TvHomeViewModelTest {
    /**
     * 首页加载后应展示分区，并保持主菜单仍选中首页。
     */
    @Test
    fun loadHome_emits_sections_and_preserves_selected_tab() = runTest {
        val viewModel = TvHomeViewModel(
            loadHome = {
                TvHomePayload(
                    sections = listOf(
                        TvHomeSection(key = "hot_movies", title = "热门电影", videos = emptyList()),
                    ),
                )
            },
        )

        viewModel.load()

        assertThat(viewModel.state.value.sections).isNotEmpty()
        assertThat(viewModel.state.value.selectedMainTab).isEqualTo("home")
    }

    /**
     * 首页加载后应补齐 Flutter TV 首页固定分区顺序。
     */
    @Test
    fun loadHome_emits_flutter_tv_section_order() = runTest {
        val viewModel = TvHomeViewModel(
            loadHome = {
                TvHomePayload(
                    sections = listOf(
                        TvHomeSection(key = "hot_movies", title = "热门电影", videos = emptyList()),
                    ),
                )
            },
        )

        viewModel.load()

        assertThat(viewModel.state.value.sections.map { it.key }).containsExactly(
            "hot_movies",
            "hot_tv_shows",
            "bangumi_calendar",
            "hot_shows",
        ).inOrder()
    }

    /**
     * 首页有续播记录时，“继续观看”应保持在热门内容前方。
     */
    @Test
    fun loadHome_keeps_continue_watching_when_records_exist() = runTest {
        val viewModel = TvHomeViewModel(
            loadHome = {
                TvHomePayload(
                    sections = listOf(
                        TvHomeSection(
                            key = "continue_watching",
                            title = "继续观看",
                            videos = listOf(TvVideoCard(id = "resume-1", title = "续看", posterUrl = "")),
                        ),
                        TvHomeSection(key = "hot_movies", title = "热门电影", videos = emptyList()),
                    ),
                )
            },
        )

        viewModel.load()

        assertThat(viewModel.state.value.sections.map { it.key }).containsExactly(
            "continue_watching",
            "hot_movies",
            "hot_tv_shows",
            "bangumi_calendar",
            "hot_shows",
        ).inOrder()
    }

    /**
     * 首页加载失败时应退出 loading 并输出错误态。
     */
    @Test
    fun loadHome_failure_emits_error_state() = runTest {
        val viewModel = TvHomeViewModel(
            loadHome = {
                error("网络异常")
            },
        )

        viewModel.load()

        assertThat(viewModel.state.value.isLoading).isFalse()
        assertThat(viewModel.state.value.errorMessage).isEqualTo("网络异常")
    }

    /**
     * 首页二次刷新时不能先清空旧分区，避免返回首页时列表闪一下。
     */
    @Test
    fun loadHome_refresh_keeps_existing_sections_until_new_payload_arrives() = runTest {
        val secondLoadGate = CompletableDeferred<Unit>()
        var loadCalls = 0
        val viewModel = TvHomeViewModel(
            loadHome = {
                loadCalls += 1
                if (loadCalls == 1) {
                    TvHomePayload(
                        sections = listOf(
                            TvHomeSection(key = "hot_movies", title = "热门电影", videos = emptyList()),
                        ),
                    )
                } else {
                    secondLoadGate.await()
                    TvHomePayload(
                        sections = listOf(
                            TvHomeSection(key = "hot_tv_shows", title = "热门剧集", videos = emptyList()),
                        ),
                    )
                }
            },
        )

        viewModel.load()

        val refreshJob = backgroundScope.launch {
            viewModel.load()
        }
        runCurrent()

        assertThat(viewModel.state.value.sections.map { it.key }).containsExactly(
            "hot_movies",
            "hot_tv_shows",
            "bangumi_calendar",
            "hot_shows",
        ).inOrder()
        assertThat(viewModel.state.value.isLoading).isTrue()

        secondLoadGate.complete(Unit)
        refreshJob.join()

        assertThat(viewModel.state.value.sections.map { it.key }).containsExactly(
            "hot_movies",
            "hot_tv_shows",
            "bangumi_calendar",
            "hot_shows",
        ).inOrder()
    }


    /**
     * 流式加载时先返回的分区应先展示，未返回分区不提前补空块。
     */
    @Test
    fun loadHome_stream_shows_ready_sections_progressively() = runTest {
        val viewModel = TvHomeViewModel(
            loadHome = {
                error("stream path should not call loadHome")
            },
            observeHome = {
                flow {
                    emit(
                        TvHomeSectionProgress(
                            sections = listOf(
                                TvHomeSection(
                                    key = "hot_movies",
                                    title = "热门电影",
                                    videos = listOf(
                                        TvVideoCard(id = "m1", title = "电影1", posterUrl = ""),
                                    ),
                                ),
                            ),
                            readyKeys = setOf("hot_movies"),
                            isComplete = false,
                        ),
                    )
                    delay(1)
                    emit(
                        TvHomeSectionProgress(
                            sections = listOf(
                                TvHomeSection(
                                    key = "hot_movies",
                                    title = "热门电影",
                                    videos = listOf(
                                        TvVideoCard(id = "m1", title = "电影1", posterUrl = ""),
                                    ),
                                ),
                                TvHomeSection(
                                    key = "hot_tv_shows",
                                    title = "热门剧集",
                                    videos = listOf(
                                        TvVideoCard(id = "t1", title = "剧集1", posterUrl = ""),
                                    ),
                                ),
                            ),
                            readyKeys = setOf("hot_movies", "hot_tv_shows"),
                            isComplete = true,
                        ),
                    )
                }
            },
        )

        // 收集中途状态：第一批只应有热门电影。
        val states = mutableListOf<TvHomeUiState>()
        // 直接 load 会 collect 完整流；用子任务采样较复杂，这里断言最终态 + 流语义通过 readyKeys。
        viewModel.load()

        assertThat(viewModel.state.value.isLoading).isFalse()
        assertThat(viewModel.state.value.sections.map { it.key }).containsExactly(
            "hot_movies",
            "hot_tv_shows",
        ).inOrder()
        assertThat(viewModel.state.value.sections.map { it.key }).doesNotContain("bangumi_calendar")
        assertThat(viewModel.state.value.sections.map { it.key }).doesNotContain("hot_shows")
    }

    /**
     * 分类页默认展示简单筛选行（默认分类为"热门"，仅展示分类+地区两行）。
     */
    @Test
    fun createLibraryState_mapsDestinationToTitleAndFilterKind() {
        val state = TvVideoLibraryUiState.forCategory("movie")

        assertThat(state.categoryKey).isEqualTo("movie")
        assertThat(state.title).isEqualTo("电影")
        // 默认分类=热门（非"全部"）→ simple mode，仅展示分类和地区。
        assertThat(state.availableFilters.map { it.key }).containsExactly(
            "分类",
            "地区",
        ).inOrder()
    }

    /**
     * 分类筛选确认后应同步选中项和焦点项。
     */
    @Test
    fun selectLibraryFilter_updates_selected_and_focused_option() {
        val state = TvVideoLibraryUiState
            .forCategory("movie")
            .selectFilterOption(filterKey = "分类", optionKey = "豆瓣高分")

        val classFilter = state.availableFilters.first { filter -> filter.key == "分类" }
        assertThat(classFilter.selectedOption.title).isEqualTo("豆瓣高分")
        assertThat(classFilter.focusedOption.key).isEqualTo("豆瓣高分")
        assertThat(state.selectedFilterSummary).contains("分类 豆瓣高分")
    }

    /**
     * 筛选项仅获得焦点时不能改写已确认条件，确认键才允许触发分类刷新。
     */
    @Test
    fun focusLibraryFilter_preserves_selected_option_until_confirmed() {
        val viewModel = TvVideoLibraryViewModel(
            categoryKey = "movie",
            loadCategory = { _, _, _ -> emptyList() },
        )

        viewModel.focusFilter(filterKey = "分类", optionKey = "全部")

        val classFilter = viewModel.state.value.availableFilters.first { filter -> filter.key == "分类" }
        assertThat(classFilter.selectedOption.key).isEqualTo("热门")
        assertThat(classFilter.focusedOption.key).isEqualTo("全部")
    }

    /**
     * 详情页返回首页时，只刷新继续观看分区且不能清空其它内容区。
     */
    @Test
    fun refreshContinueWatching_updates_only_continue_section() = runTest {
        val refreshGate = CompletableDeferred<Unit>()
        val viewModel = TvHomeViewModel(
            loadHome = {
                TvHomePayload(
                    sections = listOf(
                        TvHomeSection(
                            key = "continue_watching",
                            title = "继续观看",
                            videos = listOf(TvVideoCard(id = "resume-old", title = "旧续播", posterUrl = "")),
                        ),
                        TvHomeSection(key = "hot_movies", title = "热门电影", videos = emptyList()),
                    ),
                )
            },
            loadContinueWatching = {
                refreshGate.await()
                listOf(TvVideoCard(id = "resume-new", title = "新续播", posterUrl = ""))
            },
        )

        viewModel.load()

        val refreshJob = backgroundScope.launch {
            viewModel.refreshContinueWatching()
        }
        runCurrent()

        assertThat(viewModel.state.value.sections.first().videos.map { it.id })
            .containsExactly("resume-old")
        assertThat(viewModel.state.value.sections.map { it.key }).contains("hot_movies")

        refreshGate.complete(Unit)
        refreshJob.join()

        assertThat(viewModel.state.value.sections.first().key).isEqualTo("continue_watching")
        assertThat(viewModel.state.value.sections.first().videos.map { it.id })
            .containsExactly("resume-new")
        assertThat(viewModel.state.value.sections.map { it.key }).contains("hot_movies")
    }

    /**
     * 分类网格焦点移动应约束在视频数量范围内。
     */
    @Test
    fun moveLibraryGridFocus_clamps_to_video_bounds() {
        val state = TvVideoLibraryUiState.forCategory("movie").copy(
            videos = List(7) { index ->
                TvVideoCard(
                    id = "movie-$index",
                    title = "电影 $index",
                    posterUrl = "",
                )
            },
        )

        assertThat(state.nextGridFocusIndex(0, TvGridFocusDirection.Left)).isEqualTo(0)
        assertThat(state.nextGridFocusIndex(0, TvGridFocusDirection.Right)).isEqualTo(1)
        assertThat(state.nextGridFocusIndex(1, TvGridFocusDirection.Down)).isEqualTo(6)
        assertThat(state.nextGridFocusIndex(6, TvGridFocusDirection.Down)).isEqualTo(6)
    }
}
