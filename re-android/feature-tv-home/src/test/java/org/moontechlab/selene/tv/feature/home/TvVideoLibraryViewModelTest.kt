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
            loadCategory = { categoryKey ->
                TvVideoLibraryUiState.forCategory(categoryKey).copy(
                    videos = listOf(TvVideoCard(id = "movie-1", title = "电影", posterUrl = "")),
                )
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
            loadCategory = { categoryKey -> TvVideoLibraryUiState.forCategory(categoryKey) },
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
            loadCategory = {
                error("分类接口失败")
            },
        )

        viewModel.load()

        assertThat(viewModel.state.value.isLoading).isFalse()
        assertThat(viewModel.state.value.videos).isEmpty()
        assertThat(viewModel.state.value.errorMessage).contains("分类接口失败")
    }
}
