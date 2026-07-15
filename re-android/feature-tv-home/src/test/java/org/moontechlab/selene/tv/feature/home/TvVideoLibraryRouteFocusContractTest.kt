package org.moontechlab.selene.tv.feature.home

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * TV 分类页焦点契约测试。
 */
class TvVideoLibraryRouteFocusContractTest {
    /**
     * 未展开筛选时，分类页影视网格必须接收顶部导航向下焦点请求。
     */
    @Test
    fun route_source_attaches_content_focus_to_first_grid_card() {
        val source = readRouteSource()

        assertThat(source).contains("contentFocusRequester: FocusRequester? = null")
        assertThat(source).contains("TvLibrarySkeleton(contentFocusRequester = contentFocusRequester)")
        assertThat(source).contains("firstItemFocusRequester = if (showFilter) null else contentFocusRequester")
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
     * 电影、剧集、动漫和综艺共用的分类网格必须在倒数五行时预取，给慢接口留出缓冲时间。
     */
    @Test
    fun category_grid_prefetches_next_page_five_rows_before_end() {
        val source = readLibraryRouteSource()

        assertThat(source).contains("prefetchRows = CATEGORY_PAGE_PREFETCH_ROWS")
        assertThat(readRouteSource()).contains("private const val CATEGORY_PAGE_PREFETCH_ROWS = 5")
    }

    /**
     * 分类筛选必须从页面顶部下滑展开，隐藏重复网格标题以优先展示影视海报。
     */
    @Test
    fun category_filter_slides_from_top_and_prioritizes_grid_space() {
        val source = readLibraryRouteSource()

        assertThat(source).contains("slideInVertically(")
        assertThat(source).contains("initialOffsetY = { fullHeight -> -fullHeight }")
        assertThat(source).contains("slideOutVertically(")
        assertThat(source).contains("headerContent = if (showFilter) null else")
        assertThat(source).contains("firstItemFocusRequester = if (showFilter) null else contentFocusRequester")
    }

    /**
     * 筛选展开后内容焦点必须落到首个筛选项，且分类芯片保持紧凑以给 Grid 留出高度。
     */
    @Test
    fun category_filter_uses_compact_chips_and_owns_content_entry_focus() {
        val source = readRouteSource()
        val filterPanelSource = source
            .substringAfter("private fun TvLibraryFilterPanel(")
            .substringBefore("private fun TvLibraryFilterRow(")

        assertThat(filterPanelSource).contains("contentFocusRequester: FocusRequester? = null")
        assertThat(filterPanelSource).contains("entryFocusRequester =")
        // 宽度随文案；仅 max 防极端长文案。
        assertThat(source).contains("widthIn(max = 160.dp)")
        assertThat(source).doesNotContain("widthIn(min = 64.dp, max = 112.dp)")
        assertThat(source).contains("vertical = 8.dp")
    }

    /**
     * 筛选芯片获焦时必须使用高对比底色和深色文字，避免焦点移动过去看不清。
     */
    @Test
    fun category_filter_chip_uses_high_contrast_focus_style() {
        val source = readRouteSource()

        assertThat(source).contains("CATEGORY_FILTER_CHIP_FOCUSED_FILL")
        assertThat(source).contains("CATEGORY_FILTER_CHIP_FOCUSED_TEXT")
        assertThat(source).contains("fontWeight = if (selected || hasFocus) FontWeight.SemiBold else FontWeight.Medium")
    }

    /**
     * 紧凑筛选面板必须优先展示分类行，避免默认简单筛选只有地区一行。
     */
    @Test
    fun category_filter_prioritizes_category_row_when_default_filters_are_simple() {
        val source = readRouteSource()
        val filterPanelSource = source
            .substringAfter("private fun TvLibraryFilterPanel(")
            .substringBefore("private fun TvLibraryFilterRow(")

        assertThat(source).contains("private val CATEGORY_FILTER_PANEL_KEYS")
        assertThat(filterPanelSource).contains("CATEGORY_FILTER_PANEL_KEYS.mapNotNull")
        assertThat(source).contains("\"分类\", \"类型\", \"地区\", \"年代\"")
    }

    /**
     * 筛选展开后，从影视 Grid 按返回/Esc 须直接进入筛选栏（末行已选），
     * 禁止 moveFocus(Up) 回到上一行海报。
     */
    @Test
    fun category_filter_back_from_grid_moves_focus_up_to_nearest_filter_before_dismissal() {
        val source = readRouteSource()
        val filterPanelSource = source
            .substringAfter("private fun TvLibraryFilterPanel(")
            .substringBefore("private fun TvLibraryFilterRow(")
        val filterRowSource = source
            .substringAfter("private fun TvLibraryFilterRow(")
            .substringBefore("private fun TvLibraryFilterChip(")

        assertThat(source).contains("filterReturnFocusRequester")
        assertThat(source).contains("requestFocusBackToFilter")
        assertThat(source).contains("Key.Escape")
        assertThat(source).contains("禁止 moveFocus(Up)")
        assertThat(source).doesNotContain("focusManager.moveFocus(FocusDirection.Up)")
        assertThat(source).doesNotContain("LocalFocusManager.current")
        assertThat(filterPanelSource).contains("returnFocusRequester")
        assertThat(filterRowSource).contains("returnFocusRequester.takeIf { isSelected }")
    }

    /**
     * 分类筛选行只保留横向停留 offset，纵向离开再返回时不得把横向列表复位到首项。
     */
    @Test
    fun category_filter_rows_keep_horizontal_offset_without_restoring_last_focused_chip() {
        val source = readRouteSource()
        val filterRowSource = source
            .substringAfter("private fun TvLibraryFilterRow(")
            .substringBefore("private fun TvLibraryFilterChip(")

        assertThat(filterRowSource).contains("rememberSaveable(")
        assertThat(filterRowSource).contains("saver = LazyListState.Saver")
        assertThat(filterRowSource).contains("state = listState")
        assertThat(filterRowSource).doesNotContain("restoreFocusRequester")
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
     * 筛选项宽度随文案自适应，禁止固定 minWidth 导致二字选项焦点框比底宽。
     */
    @Test
    fun category_filter_chip_width_follows_label_without_fixed_min_width() {
        // 必须读全文件：readLibraryRouteSource 只截到筛选面板之前，不含 Chip。
        val source = readRouteSource()
        val chipSource = source
            .substringAfter("private fun TvLibraryFilterChip(")
            .substringBefore("/**\n * 将业务视频卡片转换成 TV 海报展示模型。")

        assertThat(chipSource).contains("widthIn(max = 160.dp)")
        assertThat(chipSource).doesNotContain("widthIn(min = 64.dp")
        assertThat(chipSource).doesNotContain("min = 64.dp, max = 112.dp")
        assertThat(chipSource).contains("padding(horizontal = 14.dp, vertical = 8.dp)")
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
