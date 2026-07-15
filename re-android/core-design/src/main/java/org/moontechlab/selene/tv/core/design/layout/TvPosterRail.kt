package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.unit.Dp
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 横向海报带。
 *
 * 横向边距应写在 [contentStartPadding] / [contentEndPadding]（可左右独立），
 * 不要用父级大边距夹死视口：父级若已有水平 padding，调用方应用 layout 外扩
 * （不可用负 padding，Compose 会抛 Padding must be non-negative），
 * 静止时仍靠 contentPadding 形成视觉边距，滚动时卡片可从边缘进出。
 *
 * 左右焦点使用显式邻居：末项右键 [FocusRequester.Cancel]，禁止跳出到页内其它控件
 * （例如搜索页历史标题旁的「清空」）。
 *
 * @param items 影视卡片列表。
 * @param modifier 外层修饰器。
 * @param firstItemFocusRequester 内容区入口焦点请求器，进入分组后转给最近业务海报。
 * @param onRailFocused 横向分区获焦回调，用于驱动外层页面纵向滚动。
 * @param onItemClick 卡片点击回调。
 * @param contentStartPadding 列表左 contentPadding（首卡静止左停靠，与右侧可不同）。
 * @param contentEndPadding 列表右 contentPadding（末卡末端收口，与左侧可不同）。
 * @param trailingContent 列表尾部附加内容。
 */
@Composable
fun TvPosterRail(
    items: List<TvPosterItem>,
    modifier: Modifier = Modifier,
    firstItemFocusRequester: FocusRequester? = null,
    onRailFocused: (() -> Unit)? = null,
    onItemClick: ((TvPosterItem) -> Unit)? = null,
    contentStartPadding: Dp = TvListLayoutMetrics.RailStartPadding,
    contentEndPadding: Dp = TvListLayoutMetrics.RailEndPadding,
    trailingContent: (@Composable () -> Unit)? = null,
) {
    val designMetrics = LocalTvDesignMetrics.current
    val listState = rememberSaveable(
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
        saver = LazyListState.Saver,
    ) {
        LazyListState()
    }
    // 首卡 requester 即 itemFocusRequesters[0]，单挂避免双 FocusRequester 失效。
    val firstCardFocusRequester = remember { FocusRequester() }
    val itemFocusRequesters = remember(items.size) {
        List(items.size) { index ->
            if (index == 0) firstCardFocusRequester else FocusRequester()
        }
    }
    val scrollScope = rememberCoroutineScope()
    // 最近一次真实业务获焦下标，供顶部导航下探回到当前横向浏览位置。
    var lastFocusedItemIndex by rememberSaveable(
        designMetrics.viewportWidth.toInt(),
        designMetrics.viewportHeight.toInt(),
    ) {
        mutableIntStateOf(0)
    }
    // 本轨当前会话最近获焦下标；上下跨轨进入前清零，左右相邻步进才横向推进。
    var activeFocusedIndex by remember { mutableIntStateOf(TvLayeredHorizontalFocusScroll.NoActiveIndex) }
    val lastIndex = items.lastIndex
    val hasTrailing = trailingContent != null

    LazyRow(
        modifier = modifier.posterFocusGroup(
            firstCardFocusRequester = firstCardFocusRequester,
            onVerticalEnter = {
                // 上下进轨前清会话下标，确保就近落点不会触发横向 animateScroll。
                activeFocusedIndex = TvLayeredHorizontalFocusScroll.NoActiveIndex
            },
        ),
        state = listState,
        contentPadding = PaddingValues(
            start = contentStartPadding,
            end = contentEndPadding,
        ),
        horizontalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing),
    ) {
        itemsIndexed(items, key = ::posterListItemKey) { index, item ->
            val bindsContentEntry = index == lastFocusedItemIndex
            val cardFocusRequesters = buildList {
                itemFocusRequesters.getOrNull(index)?.let { add(it) }
                if (bindsContentEntry && firstItemFocusRequester != null) {
                    if (index != 0 || firstItemFocusRequester !== firstCardFocusRequester) {
                        add(firstItemFocusRequester)
                    }
                }
            }
            val isFirst = index == 0
            val isLast = index == lastIndex
            TvPosterCard(
                item = item,
                focusRequesters = cardFocusRequesters,
                // 显式左右邻居：末项右键 Cancel，禁止几何搜索跳到「清空」等页内控件。
                focusProperties = {
                    left = if (!isFirst) {
                        itemFocusRequesters[index - 1]
                    } else {
                        // 首项左键交给系统（搜索页可回键盘；首页可回侧栏）。
                        FocusRequester.Default
                    }
                    right = when {
                        !isLast -> itemFocusRequesters[index + 1]
                        // 有「查看更多」尾卡时允许落入尾卡；无尾卡则锁死右缘（搜索推荐等）。
                        hasTrailing -> FocusRequester.Default
                        else -> FocusRequester.Cancel
                    }
                    // 上下不锁死，便于搜索推荐区与上方词块几何切换。
                    up = FocusRequester.Default
                    down = FocusRequester.Default
                },
                onFocusChanged = { hasFocus ->
                    if (hasFocus) {
                        // 仅本轨会话内左右相邻切换才横向推进；上下跨轨就近落点保持横向位置。
                        val isIntraRailHorizontalMove =
                            TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                                previousActiveIndex = activeFocusedIndex,
                                newlyFocusedIndex = index,
                            )
                        // 记录真实业务焦点，避免首卡被 LazyRow 回收后顶部下探没有目标。
                        lastFocusedItemIndex = index
                        activeFocusedIndex = index
                        // 只有刚进入当前横向分区时才驱动外层纵向滚动；
                        // 左右移动绝不能再 animateScrollToItem 整行，否则下方列表会跟着抖一下。
                        if (!isIntraRailHorizontalMove) {
                            onRailFocused?.invoke()
                        }
                        if (isIntraRailHorizontalMove) {
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
