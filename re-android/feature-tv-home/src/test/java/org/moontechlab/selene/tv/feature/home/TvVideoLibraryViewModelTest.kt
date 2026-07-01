package org.moontechlab.selene.tv.feature.home

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * 校验 TV 分类视频库状态管理契约。
 */
class TvVideoLibraryViewModelTest {
    /**
     * 分类加载成功后应展示远端视频列表。
     */
    @Test
    fun load_updates_category_videos() = runTest {
        val viewModel = TvVideoLibraryViewModel(
            categoryKey = "movie",
            loadCategory = { _, _, _ ->
                listOf(TvVideoCard(id = "movie-1", title = "电影", posterUrl = ""))
            },
        )

        viewModel.load()

        assertThat(viewModel.state.value.isLoading).isFalse()
        assertThat(viewModel.state.value.videos.map { it.id }).containsExactly("movie-1")
        assertThat(viewModel.state.value.errorMessage).isNull()
    }

    /**
     * 分类加载成功但无数据时应保持空列表成功态。
     */
    @Test
    fun load_keeps_empty_list_as_success_state() = runTest {
        val viewModel = TvVideoLibraryViewModel(
            categoryKey = "anime",
            loadCategory = { _, _, _ -> emptyList() },
        )

        viewModel.load()

        assertThat(viewModel.state.value.isLoading).isFalse()
        assertThat(viewModel.state.value.videos).isEmpty()
        assertThat(viewModel.state.value.errorMessage).isNull()
    }

    /**
     * 分类加载失败时应展示错误态。
     */
    @Test
    fun load_exposes_failure_message() = runTest {
        val viewModel = TvVideoLibraryViewModel(
            categoryKey = "show",
            loadCategory = { _, _, _ ->
                error("分类接口失败")
            },
        )

        viewModel.load()

        assertThat(viewModel.state.value.isLoading).isFalse()
        assertThat(viewModel.state.value.videos).isEmpty()
        assertThat(viewModel.state.value.errorMessage).contains("分类接口失败")
    }

    /**
     * 筛选变更应更新状态并可在重新加载后反映。
     *
     * 分类切为"全部"进入高级筛选模式，排序值已对齐为 T/U/R/S。
     */
    @Test
    fun applyFilter_updates_selected_option() = runTest {
        val viewModel = TvVideoLibraryViewModel(
            categoryKey = "movie",
            loadCategory = { _, _, _ -> emptyList() },
        )

        // 切换到"全部"进入高级筛选模式，展示全部筛选行。
        viewModel.applyFilter("分类", "全部")
        viewModel.applyFilter("排序", "S")

        val filters = viewModel.state.value.availableFilters
        assertThat(
            filters.first { it.title == "分类" }.selectedOption.key
        ).isEqualTo("全部")
        assertThat(
            filters.first { it.title == "排序" }.selectedOption.key
        ).isEqualTo("S")
    }
}
