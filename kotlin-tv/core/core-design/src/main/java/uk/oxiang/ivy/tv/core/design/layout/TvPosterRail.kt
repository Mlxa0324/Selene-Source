package uk.oxiang.ivy.tv.core.design.layout

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import kotlinx.coroutines.launch
import uk.oxiang.ivy.tv.core.design.TvTokens

/**
 * TV 横向海报带。
 *
 * @param items 影视卡片列表。
 * @param modifier 外层修饰器。
 * @param firstItemFocusRequester 内容区入口焦点请求器，进入分组后转给首张海报。
 * @param onRailFocused 横向分区获焦回调，用于驱动外层页面纵向滚动。
 * @param onItemClick 卡片点击回调。
 * @param focusMemoryGroupKey 焦点记忆分组标识，透传给每张海报卡片。
 * @param trailingContent 列表尾部附加内容。
 */
@Composable
fun TvPosterRail(
    items: List<TvPosterItem>,
    modifier: Modifier = Modifier,
    firstItemFocusRequester: FocusRequester? = null,
    onRailFocused: (() -> Unit)? = null,
    onItemClick: ((TvPosterItem) -> Unit)? = null,
    focusMemoryGroupKey: Any? = null,
    trailingContent: (@Composable () -> Unit)? = null,
) {
    val listState = rememberSaveable(saver = LazyListState.Saver) { LazyListState() }
    val firstCardFocusRequester = remember { FocusRequester() }
    val scrollScope = rememberCoroutineScope()
    var lastFocusedItemIndex by rememberSaveable { mutableIntStateOf(0) }

    LazyRow(
        modifier = modifier.posterFocusGroup(
            firstCardFocusRequester = firstCardFocusRequester,
        ),
        state = listState,
        contentPadding = PaddingValues(
            start = TvListLayoutMetrics.RailStartPadding,
            end = TvListLayoutMetrics.RailEndPadding,
        ),
        horizontalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing),
    ) {
        itemsIndexed(items, key = ::posterListItemKey) { index, item ->
            val bindsContentEntry = index == lastFocusedItemIndex
            val cardFocusRequesters = if (index == 0) {
                // 首卡承接分组首次进入；顶部导航下探优先回到最近真实获焦卡片。
                listOfNotNull(
                    firstCardFocusRequester,
                    if (bindsContentEntry) firstItemFocusRequester else null,
                )
            } else if (bindsContentEntry) {
                // 横向浏览到靠后卡片后，从顶部导航下探必须回到当前可见业务位置。
                listOfNotNull(firstItemFocusRequester)
            } else {
                emptyList()
            }
            TvPosterCard(
                item = item,
                focusRequesters = cardFocusRequesters,
                focusMemoryGroupKey = focusMemoryGroupKey,
                onFocusChanged = { hasFocus ->
                    if (hasFocus) {
                        // 记录真实业务焦点，避免首卡被 LazyRow 回收后顶部下探没有目标。
                        lastFocusedItemIndex = index
                        // 分区内任意海报获焦时，都通知外层页面把当前区块滚回视口。
                        onRailFocused?.invoke()
                        val targetIndex = TvListLayoutMetrics.resolveRailFirstVisibleItemIndex(
                            focusedIndex = index,
                            itemCount = items.size,
                        )
                        if (targetIndex != listState.firstVisibleItemIndex) {
                            scrollScope.launch {
                                // 复刻 Flutter TV 首页：第 5 张获焦后按卡片步长推动横向列表。
                                listState.animateScrollToItem(targetIndex)
                            }
                        }
                    }
                },
                onClick = onItemClick?.let { click -> { click(item) } },
            )
        }
        if (trailingContent != null) {
            item(key = "tv-poster-rail-trailing") {
                // 尾部内容用于查看更多等操作卡片，沿用同一条横向轨道。
                trailingContent()
            }
        }
    }
}
