package org.moontechlab.selene.tv.feature.favorites

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * 校验 TV 收藏夹状态管理契约。
 */
class TvFavoritesViewModelTest {
    /**
     * 加载收藏后应展示接口返回的视频列表。
     */
    @Test
    fun load_updates_favorite_videos() = runTest {
        val viewModel = TvFavoritesViewModel(
            loadFavorites = {
                listOf(TvVideoCard(id = "video-1", title = "收藏影片", posterUrl = ""))
            },
        )

        viewModel.load()

        assertThat(viewModel.state.value.videos.map { it.title }).containsExactly("收藏影片")
        assertThat(viewModel.state.value.errorMessage).isNull()
    }

    /**
     * 删除单条收藏后应同步移除当前页面卡片。
     */
    @Test
    fun deleteVideo_removes_video_after_repository_delete() = runTest {
        val deletedIds = mutableListOf<String>()
        val viewModel = TvFavoritesViewModel(
            loadFavorites = {
                listOf(
                    TvVideoCard(id = "video-1", source = "source-a", title = "收藏影片", posterUrl = ""),
                    TvVideoCard(id = "video-2", title = "保留影片", posterUrl = ""),
                )
            },
            deleteFavoriteItem = { videoId -> deletedIds += videoId },
        )

        viewModel.load()
        viewModel.deleteVideo("video-1")

        assertThat(deletedIds).containsExactly("source-a+video-1")
        assertThat(viewModel.state.value.videos.map { it.id }).containsExactly("video-2")
    }

    /**
     * 清空收藏后应回到空列表状态。
     */
    @Test
    fun clear_resets_favorites_state() = runTest {
        var cleared = false
        val viewModel = TvFavoritesViewModel(
            loadFavorites = {
                listOf(TvVideoCard(id = "video-1", title = "收藏影片", posterUrl = ""))
            },
            clearFavorites = { cleared = true },
        )

        viewModel.load()
        viewModel.clear()

        assertThat(cleared).isTrue()
        assertThat(viewModel.state.value.videos).isEmpty()
    }

    /**
     * 加载失败时应进入错误态，不能静默显示空列表。
     */
    @Test
    fun load_exposes_failure_message() = runTest {
        val viewModel = TvFavoritesViewModel(
            loadFavorites = {
                error("收藏接口失败")
            },
        )

        viewModel.load()

        assertThat(viewModel.state.value.videos).isEmpty()
        assertThat(viewModel.state.value.isLoading).isFalse()
        assertThat(viewModel.state.value.errorMessage).contains("收藏接口失败")
    }
}
