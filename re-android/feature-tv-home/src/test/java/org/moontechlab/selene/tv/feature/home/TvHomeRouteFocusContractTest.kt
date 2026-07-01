package org.moontechlab.selene.tv.feature.home

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 首页路由的遥控器焦点契约。
 */
class TvHomeRouteFocusContractTest {
    /**
     * 首页状态面板必须接收内容焦点请求器，避免加载、错误或空态时顶部导航无法下探。
     */
    @Test
    fun home_state_panels_receive_content_focus_requester() {
        val source = readRouteSource()

        assertThat(source).contains("contentFocusRequester: FocusRequester? = null")
        assertThat(source).contains("TvHomeSkeleton(contentFocusRequester = contentFocusRequester)")
        assertThat(source).contains("contentFocusRequester = contentFocusRequester")
    }

    /**
     * 首页错误态和空态必须暴露重试回调，遥控器下探后可以直接恢复加载。
     */
    @Test
    fun home_error_and_empty_panels_expose_retry_action() {
        val source = readRouteSource()

        assertThat(source).contains("onRetry: (() -> Unit)? = null")
        assertThat(source).contains("onAction = onRetry")
    }

    /**
     * 首页分区列表必须使用可纵向滚动的容器，避免焦点下移到下一排时页面停在原位。
     */
    @Test
    fun home_sections_render_inside_lazy_column_for_vertical_scroll() {
        val source = readRouteSource()

        assertThat(source).contains("val homeListState = rememberSaveable(saver = LazyListState.Saver)")
        assertThat(source).contains("LazyColumn(")
        assertThat(source).contains("state = homeListState")
    }

    /**
     * 首页海报分区获焦时必须驱动外层纵向滚动，让当前分区跟随焦点进入视口。
     */
    @Test
    fun home_route_scrolls_focused_section_into_view() {
        val source = readRouteSource()

        assertThat(source).contains("val homeScrollScope = rememberCoroutineScope()")
        assertThat(source).contains("onRailFocused = {")
        assertThat(source).contains("homeListState.animateScrollToItem(sectionIndex)")
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
}
