package org.moontechlab.selene.tv.feature.home

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvHomePayload
import org.moontechlab.selene.tv.core.data.model.TvHomeSection

/**
 * 校验 TV 首页状态管理契约。
 */
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
}
