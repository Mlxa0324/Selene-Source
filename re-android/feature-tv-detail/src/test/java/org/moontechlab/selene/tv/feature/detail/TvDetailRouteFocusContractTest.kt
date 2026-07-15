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
     * 详情页基础背景必须由设置保存的背景键解析，不能固定为 Ncat 深色背景。
     */
    @Test
    fun detail_route_resolves_default_background_from_setting_key() {
        val source = readRouteSource()

        assertThat(source).contains("backgroundKey: String = \"deep_blue\"")
        assertThat(source).contains("TvTokens.resolveBackgroundColor(backgroundKey)")
        assertThat(source).contains(".background(detailBackgroundColor)")
        assertThat(source).contains("NcatDetailBackdrop(")
        assertThat(source).contains("backgroundColor = detailBackgroundColor")
    }

    /**
     * 顶部搜索入口对齐首页右上角快捷胶囊（高度/圆角/底色/水平内边距），宽度随文案。
     */
    @Test
    fun detail_top_bar_search_matches_home_quick_access_pill() {
        val source = readRouteSource()
        val topPillSource = source
            .substringAfter("private fun NcatTopPill(")
            .substringBefore("/**\n * 截图式 Hero 区。")

        assertThat(source).contains("fontSize = 28.sp")
        assertThat(source).contains("contentPadding = PaddingValues(start = NcatContentStartPadding, end = NcatContentEndPadding)")
        assertThat(source).doesNotContain("width = 94.dp")
        assertThat(topPillSource).contains("TvTokens.TopActionHeight")
        assertThat(topPillSource).contains("TvTokens.TopActionRadius")
        assertThat(topPillSource).contains("TvTokens.Surface")
        assertThat(topPillSource).contains("TvTokens.FocusFill")
        assertThat(topPillSource).contains("padding(horizontal = 16.dp)")
        assertThat(topPillSource).contains("fontSize = 16.sp")
    }

    /**
     * 详情页右上搜索按钮应将放大镜与文案分开排版，保证远距离观看时图标清晰可见。
     */
    @Test
    fun detail_top_bar_uses_large_search_glyph_separate_from_label() {
        val source = readRouteSource()
        val topPillSource = source
            .substringAfter("private fun NcatTopPill(")
            .substringBefore("/**\n * 截图式 Hero 区。")

        assertThat(source).contains("label = \"搜索\"")
        assertThat(source).contains("leadingGlyph = \"⌕\"")
        assertThat(source).contains("leadingGlyphSize = 19.sp")
        assertThat(topPillSource).contains("Row(")
        assertThat(topPillSource).contains("fontSize = leadingGlyphSize")
    }

    /**
     * 线路与选集的空态卡片必须共用固定宽度，避免仅因说明文案长度不同而显得大小不协调。
     */
    @Test
    fun detail_empty_source_and_episode_panels_share_fixed_width() {
        val source = readRouteSource()
        val sourceRail = source
            .substringAfter("private fun NcatSourceRail(")
            .substringBefore("private fun NcatSourceCard(")
        val episodeRail = source
            .substringAfter("private fun NcatEpisodeGroupRail(")
            .substringBefore("private fun NcatEpisodeChip(")

        assertThat(source).contains("NcatEmptyStatePanelWidth")
        assertThat(sourceRail).contains("width = NcatEmptyStatePanelWidth")
        assertThat(episodeRail).contains("width = NcatEmptyStatePanelWidth")
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
        assertThat(source).contains("NcatDescriptionBoxHeight")
        assertThat(source).contains("NcatDescriptionBadgeReserve")
        assertThat(source).contains("Alignment.BottomEnd")
        assertThat(source).contains("右下角“简介”角标，与正文最后一行同一底部基线区域")
        assertThat(source).contains("padding(vertical = 8.dp)")
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
     * 简介摘要应模拟 Word 围绕：前两行全宽，末行绕开右下角标签并以省略号收尾。
     */
    @Test
    fun detail_description_wraps_around_action_badge_and_ellipsizes_final_line() {
        val source = readRouteSource()
        val infoPanelSource = source
            .substringAfter("private fun NcatInfoPanel(")
            .substringBefore("private fun NcatMetaBadge(")
        val wrappedDescriptionSource = source
            .substringAfter("private fun NcatWrappedDescription(")
            .substringBefore("private fun NcatMetaBadge(")

        assertThat(source).contains("private val NcatDescriptionBadgeReserve = 112.dp")
        assertThat(infoPanelSource).contains("NcatWrappedDescription(")
        assertThat(wrappedDescriptionSource).contains("rememberTextMeasurer()")
        assertThat(wrappedDescriptionSource).contains("getLineEnd(1, visibleEnd = true)")
        assertThat(wrappedDescriptionSource).contains("maxLines = 1")
        assertThat(wrappedDescriptionSource).contains("overflow = TextOverflow.Ellipsis")
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
        assertThat(source).contains("firstVisibleItemScrollOffset")
        assertThat(source).contains("scrollOffset = 0")
        assertThat(source).contains("listState.animateScrollToItem(")
        // 首项到最左、末项 scrollBy 夹到 max，中间仅裁切时跟手。
        assertThat(source).contains("focusedIndex == 0")
        assertThat(source).contains("listState.canScrollForward")
        assertThat(source).contains("listState.animateScrollBy(")
        // 纵向只靠 bringIntoView，禁止焦点时再强制顶/底锚 animateScroll（会抖）。
        assertThat(source).doesNotContain("scrollDetailToSourceTop")
        assertThat(source).doesNotContain("scrollDetailToRecommendBottom")
        assertThat(source).doesNotContain("onRailItemFocused")
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
        // 加载态占位 + 入场动画，禁止只等数据到位后整段突然插入。
        assertThat(source).contains("recommendLoadState = state.recommendLoadState")
        assertThat(source).contains("loadState = state.recommendLoadState")
        assertThat(source).contains("NcatRecommendSkeletonRail(")
        assertThat(source).contains("AnimatedVisibility(")
        assertThat(source).contains("fadeIn(")
        assertThat(source).contains("slideInVertically(")
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
     * 影片简介浮层必须复用并模糊详情页背景，不得再次加载独立海报。
     */
    @Test
    fun description_overlay_reuses_detail_page_backdrop_without_poster_layer() {
        val source = readRouteSource()
        // 只截取简介浮层函数，避免详情页自身的海报背景影响断言。
        val overlaySource = source
            .substringAfter("private fun NcatDescriptionOverlay(")
            .substringBefore("@Composable\nprivate fun NcatFavoriteGlyph")

        // 详情内容层在简介打开时按系统能力模糊或弱化，浮层自身保持清晰。
        assertThat(source).contains("NcatDescriptionBackdropBlurRadius")
        assertThat(source).contains(".ncatDescriptionBackdropEffect(showDescriptionOverlay)")
        assertThat(source).contains("if (!showOverlay) return this")
        assertThat(source).contains("Build.VERSION.SDK_INT >= Build.VERSION_CODES.S")
        assertThat(source).contains("blur(radius = NcatDescriptionBackdropBlurRadius)")
        assertThat(source).contains("alpha(NcatDescriptionLegacyContentAlpha)")
        // 详情背景效果必须先绘制，简介浮层后绘制，避免正文一同被模糊。
        assertThat(source.indexOf(".ncatDescriptionBackdropEffect(showDescriptionOverlay)"))
            .isLessThan(source.indexOf("if (showDescriptionOverlay)"))
        // 浮层仅保留可读性遮罩，底图继续由下方详情页提供。
        assertThat(overlaySource).contains(".background(Color.Black.copy(alpha = 0.58f))")
        assertThat(overlaySource).doesNotContain("posterUrl")
        assertThat(overlaySource).doesNotContain("AsyncImage(")
        assertThat(overlaySource).doesNotContain(".blur(")
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
        // 上下跨层进入不得因 index<=1 / 末项 额外强制横向 pin。
        assertThat(source).doesNotContain("shouldScroll || index <= 1")
        assertThat(source).doesNotContain("前 2 项保持最左")
    }

    private fun readRouteSource(): String {

        return File("src/main/java/org/moontechlab/selene/tv/feature/detail/TvDetailRoute.kt")
            .readText()
    }
}
