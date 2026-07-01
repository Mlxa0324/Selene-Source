package org.moontechlab.selene.tv.feature.settings

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 弹幕手动匹配页面渲染契约。
 */
class TvDanmakuMatchRouteContractTest {
    /**
     * 页面必须提供搜索动作和候选剧集确认入口，不能只停留在搜索词调整面板。
     */
    @Test
    fun route_exposes_search_action_and_episode_selection() {
        val source = readRouteSource()

        assertThat(source).contains("state: TvDanmakuMatchUiState")
        assertThat(source).contains("onSearchClick: () -> Unit")
        assertThat(source).contains("开始搜索")
        assertThat(source).contains("onEpisodeSelected")
        assertThat(source).contains("state.results")
        assertThat(source).contains("anime.episodes")
    }

    /**
     * 读取弹幕匹配路由源码。
     *
     * @return 当前源码文本。
     */
    private fun readRouteSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/feature/settings/TvDanmakuMatchRoute.kt")
            .readText()
    }
}
