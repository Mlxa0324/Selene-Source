package org.moontechlab.selene.tv.feature.detail

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 详情页 Route 的焦点滚动契约。
 */
class TvDetailRouteFocusContractTest {
    /**
     * 详情页必须推翻旧 IvyTV 结构，改成截图里的网飞猫详情页组件。
     */
    @Test
    fun detail_route_uses_ncat_screenshot_style_structure() {
        val source = readRouteSource()

        assertThat(source).contains("NcatDetailTopBar")
        assertThat(source).contains("NcatDetailHero")
        assertThat(source).contains("NcatSourceCard")
        assertThat(source).contains("NcatEpisodeGroupRail")
        assertThat(source).contains("NcatRecommendRail")
        assertThat(source).contains("NcatBottomActions")
        assertThat(source).contains("网飞猫")
        assertThat(source).contains("立即登录")
        assertThat(source).contains("反馈")
        assertThat(source).contains("好片推荐")
        assertThat(source).contains("返回顶部")
        assertThat(source).contains("随便看看")
        assertThat(source).doesNotContain("IvyTV")
    }

    /**
     * 详情页横向选项获焦时必须推动列表滚动，避免遥控器焦点移动到屏幕外。
     */
    @Test
    fun detail_option_rows_scroll_focused_item_into_view() {
        val source = readRouteSource()

        assertThat(source).contains("val sourceListState = rememberSaveable(saver = LazyListState.Saver)")
        assertThat(source).contains("val episodeListState = rememberSaveable(saver = LazyListState.Saver)")
        assertThat(source).contains("val episodeGroupListState = rememberSaveable(saver = LazyListState.Saver)")
        assertThat(source).contains("listState = sourceListState")
        assertThat(source).contains("state = listState")
        assertThat(source).contains("state = episodeListState")
        assertThat(source).contains("state = episodeGroupListState")
        assertThat(source).contains(".onFocusChanged { focusState ->")
        assertThat(source).contains("scrollDetailOptionIntoView(")
        assertThat(source).contains("listState.animateScrollToItem(targetIndex)")
    }

    /**
     * 读取详情页 Route 源码。
     *
     * @return Route 源码文本。
     */
    private fun readRouteSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailRoute.kt")
            .readText()
    }
}
