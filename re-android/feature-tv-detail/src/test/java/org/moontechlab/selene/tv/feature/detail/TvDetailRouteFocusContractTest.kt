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
     * 顶部按钮必须是固定宽度，避免在窄一点的 TV 视口里撑爆顶部栏。
     */
    @Test
    fun detail_top_bar_uses_fixed_width_actions() {
        val source = readRouteSource()

        assertThat(source).contains("width = 132.dp")
        assertThat(source).contains("width = 164.dp")
        assertThat(source).contains(".width(width)")
        assertThat(source).doesNotContain(".widthIn(min = 118.dp)")
    }

    /**
     * Hero 首屏播放器和右侧介绍必须平分宽度，避免播放器在 TV 详情页显得过窄。
     */
    @Test
    fun detail_hero_balances_preview_and_info_panel_widths() {
        val source = readRouteSource()

        assertThat(source).contains("NcatPreviewPanel(")
        assertThat(source).contains("modifier = Modifier.weight(1f)")
        assertThat(source).contains("NcatInfoPanel(")
        assertThat(source).contains("modifier = Modifier.weight(1f)")
        assertThat(source).doesNotContain(".width(520.dp)")
    }

    /**
     * 详情页不再默认展示续播提醒条，避免遮挡首屏 Hero。
     */
    @Test
    fun detail_route_does_not_render_resume_prompt_by_default() {
        val source = readRouteSource()

        assertThat(source).doesNotContain("NcatResumePrompt(")
        assertThat(source).doesNotContain("上次播放到第")
    }

    /**
     * 详情页自绘焦点控件必须同时支持遥控确认键和模拟器鼠标点击。
     */
    @Test
    fun detail_custom_focus_controls_support_pointer_tap() {
        val source = readRouteSource()

        assertThat(source).contains("import androidx.compose.foundation.gestures.detectTapGestures")
        assertThat(source).contains("import androidx.compose.ui.input.pointer.pointerInput")
        assertThat(source).contains("private fun Modifier.ncatClickable")
        assertThat(source).contains(".ncatClickable(onPressed)")
    }

    /**
     * 详情页横向选项获焦时必须推动列表滚动，避免遥控器焦点移动到屏幕外。
     */
    @Test
    fun detail_option_rows_scroll_focused_item_into_view() {
        val source = readRouteSource()

        assertThat(source).contains("val designMetrics = LocalTvDesignMetrics.current")
        assertThat(source).contains("val sourceListState = rememberSaveable(")
        assertThat(source).contains("val episodeListState = rememberSaveable(")
        assertThat(source).contains("val episodeGroupListState = rememberSaveable(")
        assertThat(source).contains("designMetrics.viewportWidth.toInt()")
        assertThat(source).contains("designMetrics.viewportHeight.toInt()")
        assertThat(source).contains("saver = LazyListState.Saver")
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
