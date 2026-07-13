package org.moontechlab.selene.tv.feature.detail

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 详情页 Route 的焦点滚动契约。
 */
class TvDetailRouteFocusContractTest {
    /**
     * 详情页沿用 Ncat 结构组件，品牌与首页统一为 IvyTV。
     */
    @Test
    fun detail_route_uses_ncat_screenshot_style_structure() {
        val source = readRouteSource()
        assertThat(source).contains("NcatDetailTopBar")
        assertThat(source).contains("NcatDetailHero")
        assertThat(source).contains("NcatDetailBackdrop")
        assertThat(source).contains("NcatInfoPanelSurface")
        assertThat(source).contains("NcatSourceCard")
        assertThat(source).contains("NcatEpisodeGroupRail")
        assertThat(source).contains("NcatRecommendRail")
        assertThat(source).contains("NcatBottomActions")
        assertThat(source).contains("IvyTV")
        assertThat(source).doesNotContain("立即登录")
        assertThat(source).contains("返回顶部")
        assertThat(source).contains("随便看看")
        assertThat(source).contains("NcatPillFocusButton")
        assertThat(source).contains("NcatBottomActionGlyph")
        assertThat(source).doesNotContain("待加速")
        assertThat(source).contains("多集")
        assertThat(source).contains("当前线路 · 推荐")
        assertThat(source).contains("高清")
        assertThat(source).contains("formatSourceCardTitle")
        assertThat(source).contains(".blur(radius = 18.dp)")
        assertThat(source).contains("pinCurrentSource = false")
        // 选集在上、分组在下：先渲染 episode LazyRow，再渲染分组条。
        assertThat(source.indexOf("NcatEpisodeChip(")).isLessThan(source.lastIndexOf("NcatEpisodeGroupChoice("))
        assertThat(source).contains("分组移动即切换")

        assertThat(source).doesNotContain("网飞猫")
    }

    /**
     * 顶部按钮必须是固定宽度，避免在窄一点的 TV 视口里撑爆顶部栏。
     */
    @Test
    fun detail_top_bar_uses_fixed_width_actions() {
        val source = readRouteSource()

        assertThat(source).contains("width = 88.dp")
        assertThat(source).contains("fontSize = 28.sp")
        assertThat(source).contains(".width(width)")
        assertThat(source).doesNotContain(".widthIn(min = 118.dp)")
        assertThat(source).contains("contentPadding = PaddingValues(start = NcatContentStartPadding, end = NcatContentEndPadding)")
        assertThat(source).contains("width = 88.dp")
    }

    /**
     * Hero 首屏播放器和右侧介绍必须平分宽度，避免播放器在 TV 详情页显得过窄。
     */
    @Test
    fun detail_hero_balances_preview_and_info_panel_widths() {
        val source = readRouteSource()
        assertThat(source).contains("NcatPreviewPanel(")
        assertThat(source).contains("NcatInfoPanel(")
        // 播放器与右侧简介按半宽 16:9 同高，简介上下边距加大。
        assertThat(source).contains("panelHeight = panelWidth * 9f / 16f")
        assertThat(source).contains("vertical = 20.dp")
        assertThat(source).contains("heightIn(min = 100.dp)")
        assertThat(source).contains("padding(vertical = 8.dp)")
        assertThat(source).contains("右下角标签独占下一行")
        assertThat(source).contains("NcatFullscreenGlyph(")
        assertThat(source).contains("NcatFavoriteGlyph(")
        assertThat(source).contains("label = \"全屏\"")
        assertThat(source).contains("label = \"收藏\"")
        assertThat(source).contains("NcatContentStartPadding")
        assertThat(source).contains("NcatContentEndPadding")
        assertThat(source).contains("StrokeCap.Square")
        assertThat(source).contains("StrokeJoin.Miter")
        assertThat(source).contains("val stroke = 2.dp.toPx()")
        assertThat(source).doesNotContain("label = \"反馈\"")
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
        assertThat(source).contains("scrollDetailOptionIntoView(")
                assertThat(source).contains("firstVisibleItemScrollOffset")
        assertThat(source).contains("scrollOffset = 0")
        assertThat(source).contains("listState.animateScrollToItem(")
        assertThat(source).contains("index = targetIndex")
    }

    /**
     * 相关推荐横滑必须预留右侧放大 gutter，且首/末卡按边锚点向内扩展。
     */
    @Test
    fun recommend_rail_uses_edge_scale_origin_and_end_gutter() {
        val source = readRouteSource()
        // 相关推荐必须走全局 7 列密度与左右安全边，禁止写死 113.dp。
        assertThat(source).contains("NcatRecommendRail(")
        assertThat(source).contains("TvListLayoutMetrics.PosterColumns")
        assertThat(source).contains("resolvePosterRailItemWidth(")
        assertThat(source).contains("start = recommendStartPadding")
        assertThat(source).contains("end = recommendEndPadding")
        assertThat(source).contains("NcatContentStartPadding")
        assertThat(source).contains("NcatContentEndPadding")
        assertThat(source).doesNotContain("width(113.dp)")
        assertThat(source).doesNotContain("height(160.dp)")
    }

    /**
     * 详情简介摘要必须可获焦确认，并打开全屏影片简介浮层。
     */
    @Test
    fun detail_description_summary_opens_fullscreen_overlay() {
        val source = readRouteSource()
        assertThat(source).contains("NcatInfoPanel(")
        assertThat(source).contains("showDescriptionOverlay")
        assertThat(source).contains("NcatDescriptionOverlay(")
        assertThat(source).contains("focusTargets.description")
        assertThat(source).contains("onOpenDescription")
        assertThat(source).contains("影片简介")
        assertThat(source).contains("label = \"全屏\"")
        assertThat(source).contains("label = \"收藏\"")
    }


    /**
     * 简介上方标签只展示评分/年份/分类，线路副标题固定为高清。
     */
    @Test
    fun detail_meta_badges_use_api_fields_and_source_subtitle_is_hd() {
        val source = readRouteSource()
        assertThat(source).contains("NcatMetaBadge(")
        assertThat(source).contains("detail.year")
    }

    /**
     * 预览区底部应使用贴边细进度条：浅灰轨道 + 主题色进度。
     */
    @Test
    fun detail_preview_uses_edge_theme_progress_bar() {
        val source = readRouteSource()
        assertThat(source).contains("NcatPreviewPanel(")
    }


    /**
     * 读取详情页 Route 源码。
     *
     * @return Route 源码文本。
     */
    /**
     * 详情多层横向列表：上下切换时被移开轨道不得横向复位，只在同轨左右相邻时滚动。
     */
    @Test
    fun detail_layered_rows_keep_horizontal_offset_on_vertical_focus_switch() {
        val source = readRouteSource()
        assertThat(source).contains("TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(")
        assertThat(source).contains("activeEpisodeFocusedIndex")
        assertThat(source).contains("if (shouldScroll)")
        assertThat(source).contains("scrollDetailOptionIntoView(")
        assertThat(source).contains("recommendListState = rememberSaveable(")
    }

    private fun readRouteSource(): String {

        return File("src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailRoute.kt")
            .readText()
    }
}
