package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
    onApproachingEnd: (() -> Unit)? = null,
) {
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
            start = TvListLayoutMetrics.GridHorizontalPadding,
            end = TvListLayoutMetrics.GridHorizontalPadding,
            bottom = TvListLayoutMetrics.GridBottomPadding,
        ),
        verticalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing),
        horizontalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing),
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
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.TopCenter,
            ) {
                // 单元格内居中，避免 7 列网格在宽屏上显得左重右轻。
                TvPosterCard(
                    item = item,
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
                        // 焦点落到倒数三行时提前触发下一页请求。
                        val approachingEnd = index >= items.size - columns * 3
                        if (hasFocus && approachingEnd && onApproachingEnd != null) {
                            onApproachingEnd()
                        }
                    },
                )
            }
        }
    }
}
