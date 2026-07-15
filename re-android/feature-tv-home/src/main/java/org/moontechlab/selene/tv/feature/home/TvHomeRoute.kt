package org.moontechlab.selene.tv.feature.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.runtime.remember
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.foundation.gestures.LocalBringIntoViewSpec
import androidx.compose.foundation.gestures.BringIntoViewSpec
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.TvFocusableCard
import org.moontechlab.selene.tv.core.design.layout.TvListLayoutMetrics
import org.moontechlab.selene.tv.core.design.layout.LocalTvDesignMetrics
import org.moontechlab.selene.tv.core.design.layout.TvPageScaffold
import org.moontechlab.selene.tv.core.design.layout.TvPageSection
import org.moontechlab.selene.tv.core.design.layout.TvHomeSkeleton
import org.moontechlab.selene.tv.core.design.layout.TvLibrarySkeleton
import org.moontechlab.selene.tv.core.design.layout.TvMorePosterCard
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvPosterGrid
import org.moontechlab.selene.tv.core.design.layout.TvPosterRail
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind
import org.moontechlab.selene.tv.core.design.layout.toVideoDetailKey

/** 分类页慢接口的预取提前量：焦点进入末尾五行时开始加载下一页。 */
private const val CATEGORY_PAGE_PREFETCH_ROWS = 5

/** 紧凑筛选面板保留的核心条件，优先保留分类以兼容默认简单筛选。 */
private val CATEGORY_FILTER_PANEL_KEYS = listOf("分类", "类型", "地区", "年代")

/** 分类筛选项默认底色。 */
private val CATEGORY_FILTER_CHIP_IDLE_FILL = Color(0xFF313744)

/** 分类筛选项获焦底色。 */
private val CATEGORY_FILTER_CHIP_FOCUSED_FILL = Color(0xFFF1F4F8)

/** 分类筛选项获焦文字色。 */
private val CATEGORY_FILTER_CHIP_FOCUSED_TEXT = Color(0xFF0F141A)

/**
 * TV 首页路由。
 *
 * @param state 首页界面状态。
 * @param contentFocusRequester 首页内容区入口焦点请求器。
 * @param onRetry 首页状态面板重试回调。
 * @param onVideoClick 视频卡片点击回调。
 * @param onSectionMoreClick 分区查看更多点击回调。
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TvHomeRoute(
    state: TvHomeUiState = TvHomeUiState(),
    contentFocusRequester: FocusRequester? = null,
    onRetry: (() -> Unit)? = null,
    onVideoClick: (String) -> Unit = {},
    onSectionMoreClick: (TvHomeSectionMoreTarget) -> Unit = {},
) {
    TvPageScaffold(
        modifier = Modifier.fillMaxSize(),
    ) {
        val showSkeleton = state.isLoading && state.sections.isEmpty()
        if (showSkeleton) {
            TvHomeSkeleton(contentFocusRequester = contentFocusRequester)
            return@TvPageScaffold
        }

        if (!state.errorMessage.isNullOrBlank()) {
            TvStatePanel(
                kind = TvStatePanelKind.Error,
                title = "首页加载失败",
                message = state.errorMessage,
                actionLabel = "重试",
                onAction = onRetry,
                contentFocusRequester = contentFocusRequester,
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageScaffold
        }

        if (state.sections.isEmpty()) {
            TvStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "首页暂无内容",
                message = "当前没有可展示的视频内容。",
                actionLabel = "刷新首页",
                onAction = onRetry,
                contentFocusRequester = contentFocusRequester,
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageScaffold
        }

        val firstFocusableSectionIndex = firstFocusableHomeSectionIndex(state.sections)
        val designMetrics = LocalTvDesignMetrics.current
        val homeListState = rememberSaveable(
            designMetrics.viewportWidth.toInt(),
            designMetrics.viewportHeight.toInt(),
            saver = LazyListState.Saver,
        ) {
            LazyListState()
        }
        val homeScrollScope = rememberCoroutineScope()
        val density = LocalDensity.current
        // 纵向焦点滚动：底部多留“封面标题+副标题+安全边距”，避免只露封面裁掉片名。
        val homeBringIntoViewSpec = remember(density) {
            object : BringIntoViewSpec {
                private val topMarginPx = with(density) { 24.dp.toPx() }
                // 标题行约 22sp + 副标题 13sp + 间距与放大余量。
                private val bottomMarginPx = with(density) { 108.dp.toPx() }

                override fun calculateScrollDistance(
                    offset: Float,
                    size: Float,
                    containerSize: Float,
                ): Float {
                    val trailingEdge = offset + size
                    val leadingEdge = offset
                    if (leadingEdge >= topMarginPx && trailingEdge <= containerSize - bottomMarginPx) {
                        return 0f
                    }
                    if (leadingEdge < topMarginPx && trailingEdge > containerSize - bottomMarginPx) {
                        return 0f
                    }
                    if (leadingEdge < topMarginPx) {
                        return leadingEdge - topMarginPx
                    }
                    if (trailingEdge > containerSize - bottomMarginPx) {
                        return trailingEdge - (containerSize - bottomMarginPx)
                    }
                    return 0f
                }
            }
        }
        CompositionLocalProvider(LocalBringIntoViewSpec provides homeBringIntoViewSpec) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            state = homeListState,
            // 末行分区需要额外底部空白，才能把焦点卡的标题滚出屏幕底边。
            // 底部多留一行标题+副标题余量，末轨获焦不贴底。
            contentPadding = PaddingValues(top = 8.dp, bottom = 148.dp),
            verticalArrangement = Arrangement.spacedBy(TvTokens.SectionSpacing),
        ) {
            itemsIndexed(
                items = state.sections,
                key = { _, section -> section.key },
            ) { sectionIndex, section ->
                // 分区展示模型统一处理数量截断和更多入口，Route 只负责渲染。
                val presentation = section.toHomeSectionPresentation()
                val moreTarget = presentation.moreTarget
                val sectionFocusRequester = if (sectionIndex == firstFocusableSectionIndex) {
                    contentFocusRequester
                } else {
                    null
                }
                TvPageSection(
                    title = section.title,
                    hint = if (sectionIndex == 0) "长按删除" else null,
                    insetContent = false,
                ) {
                    TvPosterRail(
                        firstItemFocusRequester = sectionFocusRequester,
                        onRailFocused = {
                            val sectionAlreadyAnchored = homeListState.firstVisibleItemIndex == sectionIndex &&
                                homeListState.firstVisibleItemScrollOffset == 0
                            if (!sectionAlreadyAnchored) {
                                homeScrollScope.launch {
                                    // 纵向换排：分区标题顶到内容区顶部，整卡（含片名）才能完整露出。
                                    homeListState.animateScrollToItem(
                                        index = sectionIndex,
                                        scrollOffset = 0,
                                    )
                                }
                            }
                        },
                        items = presentation.visibleVideos.map { video -> video.toPosterItem(section.title) },
                        trailingContent = if (presentation.showMore && moreTarget != null) {
                            {
                                TvMorePosterCard(
                                    onClick = {
                                        // 首页分区更多入口统一交给宿主路由层决定跳转页面。
                                        onSectionMoreClick(moreTarget)
                                    },
                                )
                            }
                        } else {
                            null
                        },
                        onItemClick = { item ->
                            // 首页卡片统一把视频身份交给宿主路由，避免页面直接持有 NavController。
                            onVideoClick(item.toVideoDetailKey())
                        },
                    )
                }
            }
        }
        }
    }
}

/**
 * TV 视频库分类路由。
 *
 * @param state 视频库界面状态。
 * @param contentFocusRequester 内容区入口焦点请求器。
 * @param onVideoClick 视频卡片点击回调。
 * @param onFilterOptionSelected 筛选确认回调。
 */
@Composable
fun TvVideoLibraryRoute(
    state: TvVideoLibraryUiState,
    contentFocusRequester: FocusRequester? = null,
    showFilter: Boolean = false,
    onVideoClick: (String) -> Unit = {},
    onFilterOptionSelected: ((String, String) -> Unit)? = null,
    onApproachingEnd: (() -> Unit)? = null,
) {
    // 网格返回筛选：落末行已选 chip（距列表最近）；打开面板仍落首行入口。
    val filterReturnFocusRequester = remember { FocusRequester() }
    var consumeGridBackKeyUp by remember { mutableStateOf(false) }
    LaunchedEffect(showFilter, contentFocusRequester) {
        if (showFilter) {
            // 面板完成组合后再请求焦点，确保确认键打开时直接落到首个筛选项。
            contentFocusRequester?.requestFocus()
        }
    }

    fun requestFocusBackToFilter(): Boolean {
        // 禁止 moveFocus(Up)：会先回到上一行海报（“上一个轨迹”），而不是筛选栏。
        val returned = runCatching { filterReturnFocusRequester.requestFocus() }
            .getOrDefault(false)
        if (returned) {
            return true
        }
        return contentFocusRequester?.let { requester ->
            runCatching { requester.requestFocus() }.getOrDefault(false)
        } ?: false
    }

    TvPageScaffold(
        modifier = Modifier.fillMaxSize(),
    ) {
        val showSkeleton = state.isLoading && state.videos.isEmpty()
        if (showSkeleton) {
            TvLibrarySkeleton(contentFocusRequester = contentFocusRequester)
            return@TvPageScaffold
        }

        if (!state.errorMessage.isNullOrBlank()) {
            TvStatePanel(
                kind = TvStatePanelKind.Error,
                title = "${state.title}加载失败",
                message = state.errorMessage,
                contentFocusRequester = contentFocusRequester,
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
            return@TvPageScaffold
        }

        AnimatedVisibility(
            visible = showFilter,
            // 从页面顶部向下展开，不再像单独页面一样保留首页导航区。
            enter = slideInVertically(
                initialOffsetY = { fullHeight -> -fullHeight },
            ) + fadeIn(),
            exit = slideOutVertically(
                targetOffsetY = { fullHeight -> -fullHeight },
            ) + fadeOut(),
        ) {
            TvLibraryFilterPanel(
                filters = state.availableFilters,
                contentFocusRequester = contentFocusRequester,
                returnFocusRequester = filterReturnFocusRequester,
                onOptionSelected = onFilterOptionSelected,
            )
        }

        if (state.videos.isEmpty()) {
            TvStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "${state.title}暂无内容",
                message = "当前筛选条件下没有可展示的视频。",
                contentFocusRequester = contentFocusRequester,
                modifier = Modifier.padding(horizontal = TvTokens.PageHorizontalPadding),
            )
        } else {
            TvPosterGrid(
                columns = TvListLayoutMetrics.PosterColumns,
                items = state.videos.map { video -> video.toPosterItem(state.title) },
                modifier = Modifier.onPreviewKeyEvent { event ->
                    // 筛选展开且焦点在海报列表：返回/Esc 直接进筛选栏合适项，不沿网格上移。
                    val isBackOrEsc = event.key == Key.Back || event.key == Key.Escape
                    if (!showFilter || !isBackOrEsc) {
                        return@onPreviewKeyEvent false
                    }
                    if (event.type == KeyEventType.KeyDown) {
                        consumeGridBackKeyUp = requestFocusBackToFilter()
                        return@onPreviewKeyEvent consumeGridBackKeyUp
                    }
                    if (event.type == KeyEventType.KeyUp) {
                        val shouldConsume = consumeGridBackKeyUp
                        consumeGridBackKeyUp = false
                        return@onPreviewKeyEvent shouldConsume
                    }
                    false
                },
                // 展开筛选时内容入口交给首个筛选项，避免焦点落到下方 Grid。
                firstItemFocusRequester = if (showFilter) null else contentFocusRequester,
                onItemClick = { item -> onVideoClick(item.toVideoDetailKey()) },
                // 电影、剧集、动漫和综艺共用此路由，提前五行预取下一页。
                prefetchRows = CATEGORY_PAGE_PREFETCH_ROWS,
                onApproachingEnd = onApproachingEnd,
                // 筛选已显示分类语义时隐藏 Grid 重复标题，首屏优先露出更多海报。
                headerContent = if (showFilter) null else {
                    {
                        PosterGridHeader(
                            title = state.title,
                            subtitle = categorySubtitle(state.categoryKey),
                        )
                    }
                },
            )
        }
    }
}

/**
 * TV 视频库筛选面板。
 *
 * @param filters 筛选行列表。
 * @param contentFocusRequester 筛选打开时接收入口焦点的首项请求器。
 * @param returnFocusRequester 海报列表返回键落点（末行已选 chip，距列表最近）。
 * @param onOptionSelected 筛选确认回调。
 */
@Composable
private fun TvLibraryFilterPanel(
    filters: List<TvLibraryFilter>,
    contentFocusRequester: FocusRequester? = null,
    returnFocusRequester: FocusRequester? = null,
    onOptionSelected: ((String, String) -> Unit)?,
) {
    // 仅展示四项高频条件，排序优先，给下方海报 Grid 保留更多首屏空间。
    val visibleFilters = CATEGORY_FILTER_PANEL_KEYS.mapNotNull { filterKey ->
        filters.firstOrNull { filter -> filter.key == filterKey }
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            // 紧凑深色筛选层与下方海报区分开，同时不占用额外标题高度。
            .background(
                color = TvTokens.Surface.copy(alpha = 0.94f),
                shape = RoundedCornerShape(bottomStart = 16.dp, bottomEnd = 16.dp),
            )
            .padding(
                start = TvTokens.PageHorizontalPadding,
                top = 12.dp,
                end = TvTokens.PageHorizontalPadding,
                bottom = 10.dp,
            ),
        verticalArrangement = Arrangement.spacedBy(7.dp),
    ) {
        Row(
            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "筛选",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = TvTokens.TextPrimary,
            )
            Text(
                text = "确认选择",
                style = MaterialTheme.typography.bodySmall,
                color = TvTokens.TextSecondary,
            )
        }
        visibleFilters.forEachIndexed { filterIndex, filter ->
            TvLibraryFilterRow(
                filter = filter,
                entryFocusRequester = contentFocusRequester.takeIf { filterIndex == 0 },
                // 末行已选 chip：从海报列表返回时落点，比首行更「合适」。
                returnFocusRequester = returnFocusRequester.takeIf {
                    filterIndex == visibleFilters.lastIndex
                },
                onOptionSelected = onOptionSelected,
            )
        }
    }
}

/**
 * TV 视频库单行筛选项。
 *
 * @param filter 筛选行数据。
 * @param entryFocusRequester 筛选面板入口焦点请求器，仅绑定首行首项。
 * @param returnFocusRequester 从海报列表返回时绑定到本行已选 chip。
 * @param onOptionSelected 筛选确认回调。
 */
@Composable
private fun TvLibraryFilterRow(
    filter: TvLibraryFilter,
    entryFocusRequester: FocusRequester? = null,
    returnFocusRequester: FocusRequester? = null,
    onOptionSelected: ((String, String) -> Unit)?,
) {
    val designMetrics = LocalTvDesignMetrics.current
    val listState = rememberSaveable(
        filter.key,
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
        saver = LazyListState.Saver,
    ) {
        LazyListState()
    }
    Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
    ) {
        Text(
            text = filter.title,
            modifier = Modifier.widthIn(min = 44.dp),
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = TvTokens.TextSecondary,
        )
        LazyRow(
            modifier = Modifier.weight(1f),
            state = listState,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            itemsIndexed(filter.options, key = { _, option -> option.key }) { optionIndex, option ->
                val isSelected = option.key == filter.selectedOption.key
                TvLibraryFilterChip(
                    option = option,
                    selected = isSelected,
                    focusRequesters = listOfNotNull(
                        entryFocusRequester.takeIf { optionIndex == 0 },
                        // 返回落点：优先已选项；若已选项不在首项则单独挂 requester。
                        returnFocusRequester.takeIf { isSelected },
                    ),
                    onSelected = {
                        onOptionSelected?.invoke(filter.key, option.key)
                    },
                )
            }
        }
    }
}

/**
 * TV 视频库筛选选项卡片。
 *
 * 宽度随文案自适应（二字「全部」、四字「欧美剧」等左右内边距一致），
 * 禁止写死 minWidth，否则短文案焦点框比底宽、横移几何也对不齐。
 *
 * @param option 筛选选项。
 * @param selected 是否已确认选中。
 * @param focusRequesters 面板入口时绑定到真实筛选项的焦点请求器。
 * @param onSelected 筛选确认回调。
 */
@Composable
private fun TvLibraryFilterChip(
    option: TvLibraryFilterOption,
    selected: Boolean,
    focusRequesters: List<FocusRequester> = emptyList(),
    onSelected: () -> Unit,
) {
    var hasFocus by remember { mutableStateOf(false) }
    val backgroundColor = when {
        selected -> TvTokens.Accent
        hasFocus -> CATEGORY_FILTER_CHIP_FOCUSED_FILL
        else -> CATEGORY_FILTER_CHIP_IDLE_FILL
    }
    val textColor = when {
        selected -> TvTokens.TextPrimary
        hasFocus -> CATEGORY_FILTER_CHIP_FOCUSED_TEXT
        else -> TvTokens.TextPrimary
    }
    val chipShape = RoundedCornerShape(TvTokens.CardRadius)
    TvFocusableCard(
        // 不设固定 min 宽：外层焦点框与内层底同宽，随文字伸缩。
        // 仅保留 max，避免极端长文案撑破一行。
        modifier = Modifier
            .widthIn(max = 160.dp)
            .onFocusChanged { focusState ->
                // 视觉高亮直接跟随真实 Compose 焦点，不再额外记忆离开前的筛选项。
                hasFocus = focusState.isFocused
            },
        focusRequesters = focusRequesters,
        onPressed = onSelected,
    ) {
        // 内层背景与焦点描边同宽；水平 padding 固定，二字/四字仅内容区变宽。
        Text(
            text = option.title,
            modifier = Modifier
                .background(
                    color = backgroundColor,
                    shape = chipShape,
                )
                .padding(horizontal = 14.dp, vertical = 8.dp),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = if (selected || hasFocus) FontWeight.SemiBold else FontWeight.Medium,
            color = textColor,
        )
    }
}

/**
 * 将业务视频卡片转换成 TV 海报展示模型。
 *
 * @param fallbackSubtitle 无年份和来源时的兜底副标题。
 * @return 可直接渲染的海报卡片。
 */
private fun TvVideoCard.toPosterItem(fallbackSubtitle: String): TvPosterItem {
    return TvPosterItem(
        id = id,
        source = source,
        title = title,
        subtitle = posterSubtitle(fallbackSubtitle),
        posterUrl = posterUrl,
        totalEpisodes = totalEpisodes,
        episodeIndex = episodeIndex,
        progressFraction = playbackProgressFraction(),
    )
}


/**
 * 生成贴近 Flutter TV 卡片的副标题。
 *
 * @param fallbackSubtitle 分区或页面兜底文案。
 * @return 卡片副标题。
 */
private fun TvVideoCard.posterSubtitle(fallbackSubtitle: String): String {
    if ((playTime > 0 || episodeIndex > 1) && sourceName.isNotBlank()) {
        // 续播卡片下方只展示线路，集数和进度交给封面徽标与进度条表达。
        return sourceName
    }
    val parts = buildList {
        if (year.isNotBlank()) {
            add(year)
        }
        if (sourceName.isNotBlank()) {
            add(sourceName)
        }
    }
    return parts.joinToString(" · ").ifBlank { fallbackSubtitle }
}

/**
 * 计算播放进度比例。
 *
 * @return 0..1 之间的播放进度，缺少总时长时返回 0。
 */
private fun TvVideoCard.playbackProgressFraction(): Float {
    if (playTime <= 0 || totalTime <= 0) {
        return 0f
    }
    return playTime.toFloat() / totalTime.toFloat()
}

/**
 * 分类副标题文案。
 */
private fun categorySubtitle(categoryKey: String): String {
    return when (categoryKey) {
        "movie" -> "豆瓣精选"
        "tv" -> "豆瓣精选"
        "anime" -> "Bangumi 精选"
        "show" -> "豆瓣精选"
        else -> ""
    }
}

/**
 * TV 海报网格头部 —— 标题+副标题，不获焦，随网格滚动。
 *
 * 网格本身已有左右 contentPadding，这里不再叠加水平缩进，避免标题视觉缩进偏大。
 * 颜色走 TV 主题 token，避免 Material onSurface 在暗色底上偏灰看不清。
 */
@Composable
private fun PosterGridHeader(
    title: String,
    subtitle: String,
) {
    // 与 TvScrollablePageHeader 同密度：页头收紧，首屏多露出一行海报。
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 6.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge.copy(
                fontSize = 22.sp,
                fontWeight = FontWeight.ExtraBold,
            ),
            color = TvTokens.TextPrimary,
        )
        if (subtitle.isNotBlank()) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp),
                color = TvTokens.TextSecondary,
            )
        }
    }
}
