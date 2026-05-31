package org.moontechlab.selene.tv.feature.live

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 TV 直播页面状态契约。
 */
class TvLiveRouteTest {
    /**
     * 有选中频道时应展示频道名称。
     */
    @Test
    fun selectedChannelTitle_returns_selected_channel_name() {
        val state = TvLiveUiState(
            channels = listOf(
                TvLiveChannel(
                    id = "cctv-1",
                    name = "CCTV-1",
                    group = "央视",
                    currentProgram = "新闻",
                ),
            ),
            selectedChannelId = "cctv-1",
        )

        assertThat(selectedChannelTitle(state)).isEqualTo("CCTV-1")
    }

    /**
     * 未选中频道时应展示默认提示。
     */
    @Test
    fun selectedChannelTitle_returns_default_when_channel_missing() {
        val state = TvLiveUiState(
            channels = listOf(
                TvLiveChannel(
                    id = "cctv-1",
                    name = "CCTV-1",
                    group = "央视",
                    currentProgram = "新闻",
                ),
            ),
            selectedChannelId = "missing",
        )

        assertThat(selectedChannelTitle(state)).isEqualTo("未选择频道")
    }
}
