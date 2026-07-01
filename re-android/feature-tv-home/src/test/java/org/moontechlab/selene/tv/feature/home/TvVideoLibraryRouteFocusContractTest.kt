package org.moontechlab.selene.tv.feature.home

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * TV 分类页焦点契约测试。
 */
class TvVideoLibraryRouteFocusContractTest {
    /**
     * 分类页影视网格必须接收顶部导航向下焦点请求。
     */
    @Test
    fun route_source_attaches_content_focus_to_first_grid_card() {
        val source = readRouteSource()

        assertThat(source).contains("contentFocusRequester: FocusRequester? = null")
        assertThat(source).contains("TvLibrarySkeleton(contentFocusRequester = contentFocusRequester)")
        assertThat(source).contains("firstItemFocusRequester = contentFocusRequester")
    }

    /**
     * 分类页影视网格必须传入带来源的视频点击回调，否则详情页无法精准取源。
     */
    @Test
    fun route_source_passes_video_click_to_grid_cards() {
        val source = readRouteSource()

        assertThat(source).contains("onVideoClick: (String) -> Unit = {}")
        assertThat(source).contains("onItemClick = { item -> onVideoClick(item.toVideoDetailKey()) }")
    }

    /**
     * 分类页空态和错误态必须承接顶部导航下探入口。
     */
    @Test
    fun route_source_attaches_content_focus_to_empty_and_error_states() {
        val source = readLibraryRouteSource()

        assertThat(source).contains("title = \"${'$'}{state.title}加载失败\"")
        assertThat(source).contains("title = \"${'$'}{state.title}暂无内容\"")
        assertThat(source).contains("contentFocusRequester = contentFocusRequester")
    }

    /**
     * 读取当前模块的 Route 源码。
     *
     * @return Route 源码文本。
     */
    private fun readRouteSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/feature/home/TvHomeRoute.kt")
            .readText()
    }

    /**
     * 读取分类页路由函数源码。
     *
     * @return TvVideoLibraryRoute 函数源码文本。
     */
    private fun readLibraryRouteSource(): String {
        return readRouteSource()
            .substringAfter("fun TvVideoLibraryRoute(")
            .substringBefore("/**\n * TV 视频库筛选面板。")
    }
}
