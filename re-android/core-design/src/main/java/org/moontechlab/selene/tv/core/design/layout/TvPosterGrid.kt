package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.unit.Dp
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 纵向海报网格。
 *
 * @param items 影视卡片列表。
 * @param columns 每行列数。
 * @param modifier 外层修饰器。
 * @param headerContent 网格顶部内容（全宽 span，随网格滚动）。
 * @param firstItemFocusRequester 内容区入口焦点请求器，进入分组后转给首张海报。
 * @param onItemClick 卡片点击回调。
 * @param contentHorizontalPadding 网格左右 contentPadding；容器内嵌时可减小。
 * @param contentBottomPadding 网格底部 contentPadding。
 * @param horizontalSpacing 列间距。
 * @param verticalSpacing 行间距。
 * @param fillCellWidth true 时卡片铺满单元格宽（搜索 5 列更舒展）；false 用全局固定海报宽。
 * @param prefetchRows 距离末尾多少行时开始触发下一页预取。
 * @param onApproachingEnd 焦点接近列表末尾时触发，用于触底加载下一页。
 */
@Composable
fun TvPosterGrid(
    items: List<TvPosterItem>,
    columns: Int,
    modifier: Modifier = Modifier,
    headerContent: (@Composable () -> Unit)? = null,
    firstItemFocusRequester: FocusRequester? = null,
    onItemClick: ((TvPosterItem) -> Unit)? = null,
    contentHorizontalPadding: Dp = TvListLayoutMetrics.GridHorizontalPadding,
    contentBottomPadding: Dp = TvListLayoutMetrics.GridBottomPadding,
    horizontalSpacing: Dp = TvTokens.CardSpacing,
    verticalSpacing: Dp = TvTokens.CardSpacing,
    fillCellWidth: Boolean = false,
    prefetchRows: Int = 3,
    onApproachingEnd: (() -> Unit)? = null,
) {
    // 预取行数至少保留一行，避免外部错误配置导致末尾分页失效。
    val resolvedPrefetchRows = prefetchRows.coerceAtLeast(1)
    val designMetrics = LocalTvDesignMetrics.current
    val gridState = rememberSaveable(
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
        saver = LazyGridState.Saver,
    ) {
        LazyGridState()
    }
    val firstCardFocusRequester = remember { FocusRequester() }
    val scrollScope = rememberCoroutineScope()
    var lastFocusedItemIndex by rememberSaveable(
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
    ) {
        mutableIntStateOf(0)
    }

    LazyVerticalGrid(
        columns = GridCells.Fixed(columns),
        modifier = modifier.posterFocusGroup(
            firstCardFocusRequester = firstCardFocusRequester,
        ),
        state = gridState,
        contentPadding = PaddingValues(
            start = contentHorizontalPadding,
            end = contentHorizontalPadding,
            bottom = contentBottomPadding,
        ),
        verticalArrangement = Arrangement.spacedBy(verticalSpacing),
        horizontalArrangement = Arrangement.spacedBy(horizontalSpacing),
    ) {
        // 网格头部（全宽，不获焦，随网格一起滚动）
        if (headerContent != null) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                headerContent()
            }
        }
        itemsIndexed(items, key = ::posterListItemKey) { index, item ->
            val bindsContentEntry = index == lastFocusedItemIndex
            val cardFocusRequesters = if (index == 0) {
                // 首卡承接网格首次进入；顶部导航下探优先回到最近真实获焦卡片。
                listOfNotNull(
                    firstCardFocusRequester,
                    if (bindsContentEntry) firstItemFocusRequester else null,
                )
            } else if (bindsContentEntry) {
                // 纵向浏览到靠后卡片后，从顶部导航下探必须回到当前业务位置。
                listOfNotNull(firstItemFocusRequester)
            } else {
                emptyList()
            }
            BoxWithConstraints(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.TopCenter,
            ) {
                // fillCellWidth：搜索 5 列铺满格宽；首页等仍用固定海报宽居中。
                val resolvedCardWidth = if (fillCellWidth) {
                    maxWidth
                } else {
                    TvTokens.PosterWidth
                }
                TvPosterCard(
                    item = item,
                    cardWidth = resolvedCardWidth,
                    focusRequesters = cardFocusRequesters,
                    onClick = onItemClick?.let { click -> { click(item) } },
                    onFocusChanged = { hasFocus ->
                        if (hasFocus) {
                            // 记录真实业务焦点，避免首卡被 LazyGrid 回收后顶部下探没有目标。
                            lastFocusedItemIndex = index
                            if (index != gridState.firstVisibleItemIndex) {
                                scrollScope.launch {
                                    // 网格按行滚动，保持当前行在重新入场时稳定可见。
                                    gridState.animateScrollToItem(index)
                                }
                            }
                        }
                        // 焦点进入预取阈值时后台请求下一页，避免用户触底后停在加载态。
                        val approachingEnd = index >= items.size - columns * resolvedPrefetchRows
                        if (hasFocus && approachingEnd && onApproachingEnd != null) {
                            onApproachingEnd()
                        }
                    },
                )
            }
        }
    }
}
