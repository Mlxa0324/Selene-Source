package org.moontechlab.selene.tv.feature.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.TvFocusableCard
import org.moontechlab.selene.tv.core.design.layout.TvPageScaffold
import org.moontechlab.selene.tv.core.design.layout.TvPageSection
import org.moontechlab.selene.tv.core.design.layout.TvMorePosterCard
import org.moontechlab.selene.tv.core.design.layout.TvPosterItem
import org.moontechlab.selene.tv.core.design.layout.TvPosterGrid
import org.moontechlab.selene.tv.core.design.layout.TvPosterRail
import org.moontechlab.selene.tv.core.design.layout.TvStatePanel
import org.moontechlab.selene.tv.core.design.layout.TvStatePanelKind

/**
 * TV 首页路由。
 *
 * @param state 首页界面状态。
 * @param onVideoClick 视频卡片点击回调。
 * @param onSectionMoreClick 分区查看更多点击回调。
 */
@Composable
fun TvHomeRoute(
    state: TvHomeUiState = TvHomeUiState(),
    onVideoClick: (String) -> Unit = {},
    onSectionMoreClick: (TvHomeSectionMoreTarget) -> Unit = {},
) {
    TvPageScaffold(
        modifier = Modifier.fillMaxSize(),
    ) {
        if (state.isLoading) {
            TvStatePanel(
                kind = TvStatePanelKind.Loading,
                title = "首页加载中",
                message = "正在同步继续观看、热门内容和收藏快照。",
            )
            return@TvPageScaffold
        }

        if (!state.errorMessage.isNullOrBlank()) {
            TvStatePanel(
                kind = TvStatePanelKind.Error,
                title = "首页加载失败",
                message = state.errorMessage,
                actionLabel = "重试",
            )
            return@TvPageScaffold
        }

        if (state.sections.isEmpty()) {
            TvStatePanel(
                kind = TvStatePanelKind.Empty,
                title = "首页暂无内容",
                message = "当前没有可展示的视频内容。",
                actionLabel = "刷新首页",
            )
            return@TvPageScaffold
        }

        state.sections.forEachIndexed { index, section ->
            // 分区展示模型统一处理数量截断和更多入口，Route 只负责渲染。
            val presentation = section.toHomeSectionPresentation()
            val moreTarget = presentation.moreTarget
            TvPageSection(
                title = section.title,
                hint = if (index == 0) "长按删除" else null,
            ) {
                TvPosterRail(
                    items = presentation.visibleVideos.map { video ->
                        TvPosterItem(
                            id = video.id,
                            title = video.title,
                            subtitle = section.title,
                            posterUrl = video.posterUrl,
                        )
                    },
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
                        onVideoClick(item.id)
                    },
                )
            }
        }
    }
}

/**
 * TV 视频库分类路由。
 *
 * @param state 视频库界面状态。
 * @param onFilterOptionSelected 筛选确认回调。
 * @param onFilterOptionFocused 筛选焦点变化回调。
 */
@Composable
fun TvVideoLibraryRoute(
    state: TvVideoLibraryUiState,
    onFilterOptionSelected: ((String, String) -> Unit)? = null,
    onFilterOptionFocused: ((String, String) -> Unit)? = null,
) {
    TvPageScaffold(
        title = state.title,
        modifier = Modifier.fillMaxSize(),
    ) {
        if (state.isLoading) {
            TvStatePanel(
                kind = TvStatePanelKind.Loading,
                title = "${state.title}加载中",
                message = "正在拉取分类内容。",
            )
            return@TvPageScaffold
        }

        if (!state.errorMessage.isNullOrBlank()) {
            TvStatePanel(
                kind = TvStatePanelKind.Error,
                title = "${state.title}加载失败",
                message = state.errorMessage,
            )
            return@TvPageScaffold
        }

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

        TvPageSection(
            title = state.title,
            hint = if (state.videos.isEmpty()) "暂无内容" else "${state.videos.size} 个视频",
        ) {
            if (state.videos.isEmpty()) {
                TvStatePanel(
                    kind = TvStatePanelKind.Empty,
                    title = "${state.title}暂无内容",
                    message = "当前筛选条件下没有可展示的视频。",
                )
            } else {
                TvPosterGrid(
                    columns = 7,
                    items = state.videos.map { video ->
                        TvPosterItem(
                            id = video.id,
                            title = video.title,
                            subtitle = state.title,
                            posterUrl = video.posterUrl,
                        )
                    },
                )
            }
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
            contentPadding = PaddingValues(end = TvTokens.PageHorizontalPadding),
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
