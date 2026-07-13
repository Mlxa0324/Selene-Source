package org.moontechlab.selene.tv.feature.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
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
                private val bottomMarginPx = with(density) { 96.dp.toPx() }

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
            contentPadding = PaddingValues(bottom = 120.dp),
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
 * @param onFilterOptionFocused 筛选焦点变化回调。
 */
@Composable
fun TvVideoLibraryRoute(
    state: TvVideoLibraryUiState,
    contentFocusRequester: FocusRequester? = null,
    showFilter: Boolean = false,
    onVideoClick: (String) -> Unit = {},
    onFilterOptionSelected: ((String, String) -> Unit)? = null,
    onFilterOptionFocused: ((String, String) -> Unit)? = null,
    onApproachingEnd: (() -> Unit)? = null,
) {
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
            enter = expandVertically(),
            exit = shrinkVertically(),
        ) {
            TvPageSection(
                title = "筛选",
                hint = state.selectedFilterSummary,
            ) {
                TvLibraryFilterPanel(
                    filters = state.availableFilters,
                    onOptionSelected = onFilterOptionSelected,
                    onOptionFocused = onFilterOptionFocused,
                )
            }
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
                firstItemFocusRequester = contentFocusRequester,
                onItemClick = { item -> onVideoClick(item.toVideoDetailKey()) },
                onApproachingEnd = onApproachingEnd,
                headerContent = {
                    PosterGridHeader(
                        title = state.title,
                        subtitle = categorySubtitle(state.categoryKey),
                    )
                },
            )
        }
    }
}

/**
 * TV 视频库筛选面板。
 *
 * @param filters 筛选行列表。
 * @param onOptionSelected 筛选确认回调。
 * @param onOptionFocused 筛选焦点变化回调。
 */
@Composable
private fun TvLibraryFilterPanel(
    filters: List<TvLibraryFilter>,
    onOptionSelected: ((String, String) -> Unit)?,
    onOptionFocused: ((String, String) -> Unit)?,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        filters.forEach { filter ->
            TvLibraryFilterRow(
                filter = filter,
                onOptionSelected = onOptionSelected,
                onOptionFocused = onOptionFocused,
            )
        }
    }
}

/**
 * TV 视频库单行筛选项。
 *
 * @param filter 筛选行数据。
 * @param onOptionSelected 筛选确认回调。
 * @param onOptionFocused 筛选焦点变化回调。
 */
@Composable
private fun TvLibraryFilterRow(
    filter: TvLibraryFilter,
    onOptionSelected: ((String, String) -> Unit)?,
    onOptionFocused: ((String, String) -> Unit)?,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            text = filter.title,
            modifier = Modifier.widthIn(min = 42.dp),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
        LazyRow(
            modifier = Modifier.weight(1f),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(
                end = TvTokens.PageHorizontalPadding,
            ),
        ) {
            items(filter.options, key = TvLibraryFilterOption::key) { option ->
                TvLibraryFilterChip(
                    option = option,
                    selected = option.key == filter.selectedOption.key,
                    focused = option.key == filter.focusedOption.key,
                    onSelected = {
                        onOptionSelected?.invoke(filter.key, option.key)
                    },
                    onFocused = {
                        onOptionFocused?.invoke(filter.key, option.key)
                    },
                )
            }
        }
    }
}

/**
 * TV 视频库筛选选项卡片。
 *
 * @param option 筛选选项。
 * @param selected 是否已确认选中。
 * @param focused 是否为状态记录的焦点。
 * @param onSelected 筛选确认回调。
 * @param onFocused 焦点进入回调。
 */
@Composable
private fun TvLibraryFilterChip(
    option: TvLibraryFilterOption,
    selected: Boolean,
    focused: Boolean,
    onSelected: () -> Unit,
    onFocused: () -> Unit,
) {
    val backgroundColor = when {
        selected -> TvTokens.Accent
        focused -> TvTokens.FocusFill
        else -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.7f)
    }
    TvFocusableCard(
        modifier = Modifier
            .widthIn(min = 84.dp)
            .onFocusChanged { focusState ->
                if (focusState.isFocused) {
                    // 焦点进入时把筛选停留位置回传给状态层，支持从 Grid 返回筛选区。
                    onFocused()
                }
            },
        onPressed = onSelected,
    ) {
        // 内层背景标记已选与最近焦点，外层焦点描边交给 TvFocusableCard。
        Text(
            text = option.title,
            modifier = Modifier
                .background(
                    color = backgroundColor,
                    shape = RoundedCornerShape(TvTokens.CardRadius),
                )
                .padding(horizontal = 16.dp, vertical = 10.dp),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
            color = if (selected) TvTokens.TextPrimary else MaterialTheme.colorScheme.onSurface,
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
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 10.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.ExtraBold,
            color = TvTokens.TextPrimary,
        )
        if (subtitle.isNotBlank()) {
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = TvTokens.TextSecondary,
            )
        }
    }
}
