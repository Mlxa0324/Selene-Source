package org.moontechlab.selene.tv.feature.history

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * 校验 TV 播放历史状态管理契约。
 */
class TvHistoryViewModelTest {
    /**
     * 加载历史后应展示接口返回的视频列表。
     */
    @Test
    fun load_updates_history_videos() = runTest {
        val viewModel = TvHistoryViewModel(
            loadHistory = {
                listOf(TvVideoCard(id = "video-1", title = "第一集", posterUrl = ""))
            },
        )

        viewModel.load()

        assertThat(viewModel.state.value.videos.map { it.id }).containsExactly("video-1")
        assertThat(viewModel.state.value.errorMessage).isNull()
    }

    /**
     * 删除单条历史后应同步移除当前页面卡片。
     */
    @Test
    fun deleteVideo_removes_video_after_repository_delete() = runTest {
        val deletedIds = mutableListOf<String>()
        val viewModel = TvHistoryViewModel(
            loadHistory = {
                listOf(
                    TvVideoCard(id = "video-1", source = "source-a", title = "第一集", posterUrl = ""),
                    TvVideoCard(id = "video-2", title = "第二集", posterUrl = ""),
                )
            },
            deleteHistoryItem = { videoId -> deletedIds += videoId },
        )

        viewModel.load()
        viewModel.deleteVideo("video-1")

        assertThat(deletedIds).containsExactly("source-a+video-1")
        assertThat(viewModel.state.value.videos.map { it.id }).containsExactly("video-2")
    }

    /**
     * 清空历史后应回到空列表状态。
     */
    @Test
    fun clear_resets_history_state() = runTest {
        var cleared = false
        val viewModel = TvHistoryViewModel(
            loadHistory = {
                listOf(TvVideoCard(id = "video-1", title = "第一集", posterUrl = ""))
            },
            clearHistory = { cleared = true },
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
        val viewModel = TvHistoryViewModel(
            loadHistory = {
                error("历史接口失败")
            },
        )

        viewModel.load()

        assertThat(viewModel.state.value.videos).isEmpty()
        assertThat(viewModel.state.value.isLoading).isFalse()
        assertThat(viewModel.state.value.errorMessage).contains("历史接口失败")
    }
}
