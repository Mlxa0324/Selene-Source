package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
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
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import androidx.compose.ui.unit.Dp
import kotlin.math.abs
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.rememberTvEdgeShakeState
import org.moontechlab.selene.tv.core.design.focus.tvEdgeShake

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
 * @param onItemLongClick 卡片长按 / 菜单键回调（首页继续观看删除等）。
 * @param contentStartPadding 列表左 contentPadding（首卡静止左停靠，与右侧可不同）。
 * @param contentEndPadding 列表右 contentPadding（末卡末端收口，与左侧可不同）。
 * @param onLeftFromFirst 首项再按左时的显式出口（如搜索页回键盘分带）；null 时首项左键走系统几何搜索。
 * @param upFromFirst 首项上键显式出口（如首页「去登录」提示条）；null 时走系统几何搜索。
 * @param trailingContent 列表尾部附加内容。
 */
@Composable
fun TvPosterRail(
    items: List<TvPosterItem>,
    modifier: Modifier = Modifier,
    firstItemFocusRequester: FocusRequester? = null,
    onRailFocused: (() -> Unit)? = null,
    onItemClick: ((TvPosterItem) -> Unit)? = null,
    onItemLongClick: ((TvPosterItem) -> Unit)? = null,
    contentStartPadding: Dp = TvListLayoutMetrics.RailStartPadding,
    contentEndPadding: Dp = TvListLayoutMetrics.RailEndPadding,
    onLeftFromFirst: (() -> Unit)? = null,
    upFromFirst: FocusRequester? = null,
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
    val requestItemFocus: suspend (Int) -> Boolean = { index ->
        runCatching {
            itemFocusRequesters.getOrNull(index)?.requestFocus() == true
        }.getOrDefault(false)
    }

    Column(modifier = modifier) {
        // 顶栏下探入口始终组合：上次卡片横向屏外时也能 scroll + 就近落焦。
        if (firstItemFocusRequester != null && items.isNotEmpty()) {
            TvLazyListFocusEntry(
                entryFocusRequester = firstItemFocusRequester,
                preferredIndex = { lastFocusedItemIndex },
                itemCount = items.size,
                listState = listState,
                requestItemFocus = requestItemFocus,
                scrollPreferredIntoView = true,
                scope = scrollScope,
            )
        }
    LazyRow(
        modifier = Modifier.posterFocusGroup(
            firstCardFocusRequester = firstCardFocusRequester,
            onVerticalEnter = {
                // 上下进轨前清会话下标，确保就近落点不会触发横向 animateScroll。
                activeFocusedIndex = TvLayeredHorizontalFocusScroll.NoActiveIndex
            },
            // 上下进轨：可见项就近落焦；项在 Lazy 视口外时先组合再进，避免整轨无法获焦。
            listState = listState,
            preferredIndex = { lastFocusedItemIndex },
            itemCount = items.size,
            requestItemFocus = requestItemFocus,
        ),
        state = listState,
        contentPadding = PaddingValues(
            start = contentStartPadding,
            end = contentEndPadding,
        ),
        horizontalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing),
    ) {
        itemsIndexed(items, key = ::posterListItemKey) { index, item ->
            // 内容入口改由 TvLazyListFocusEntry 独占 firstItemFocusRequester，避免双挂失效。
            val cardFocusRequesters = buildList {
                itemFocusRequesters.getOrNull(index)?.let { add(it) }
            }
            val isFirst = index == 0
            val isLast = index == lastIndex
            val edgeShake = rememberTvEdgeShakeState()
            // 首项显式左出 或 首/末边界抖动：挂在真实 focusable 上拦截方向键。
            val horizontalEdgePreviewKey: (androidx.compose.ui.input.key.KeyEvent) -> Boolean = { event ->
                when {
                    // 首项显式左出：回键盘等业务出口，不抖。
                    isFirst && onLeftFromFirst != null && event.key == Key.DirectionLeft -> {
                        if (event.type == KeyEventType.KeyDown) {
                            onLeftFromFirst.invoke()
                        }
                        event.type == KeyEventType.KeyDown || event.type == KeyEventType.KeyUp
                    }
                    // 首项再左：到底抖动（无业务出口时）。
                    isFirst && onLeftFromFirst == null && event.key == Key.DirectionLeft -> {
                        edgeShake.consumeBoundaryKey(event = event, left = true)
                    }
                    // 末项再右（无尾卡）：到底抖动。
                    isLast && !hasTrailing && event.key == Key.DirectionRight -> {
                        edgeShake.consumeBoundaryKey(event = event, right = true)
                    }
                    else -> false
                }
            }
            TvPosterCard(
                item = item,
                modifier = Modifier.tvEdgeShake(edgeShake),
                focusRequesters = cardFocusRequesters,
                // 显式左右邻居：末项右键 Cancel，禁止几何搜索跳到「清空」等页内控件。
                focusProperties = {
                    left = if (!isFirst) {
                        itemFocusRequesters[index - 1]
                    } else {
                        // 首项左：preview 接管（业务出口或抖动），禁止 Default 二次跳焦。
                        FocusRequester.Cancel
                    }
                    right = when {
                        !isLast -> itemFocusRequesters[index + 1]
                        // 有「查看更多」尾卡时允许落入尾卡；无尾卡则锁死右缘（搜索推荐等）。
                        hasTrailing -> FocusRequester.Default
                        else -> FocusRequester.Cancel
                    }
                    // 首项可显式上出（首页登录提示）；其余上下交给系统几何。
                    up = when {
                        isFirst && upFromFirst != null -> upFromFirst
                        else -> FocusRequester.Default
                    }
                    down = FocusRequester.Default
                },
                onPreviewKey = horizontalEdgePreviewKey,
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
                            scrollScope.launch {
                                // 中心带跟焦：左右越过中线才 scrollBy，禁止 pin 到 firstVisible 左缘。
                                listState.scrollFocusedItemWithCenterBand(index)
                            }
                        }
                    }
                },
                onClick = onItemClick?.let { click -> { click(item) } },
                onLongClick = onItemLongClick?.let { longClick -> { longClick(item) } },
            )
        }
        if (trailingContent != null) {
            item(key = "tv-poster-rail-trailing") {
                // 尾部内容用于查看更多等操作卡片，沿用同一条横向轨道。
                trailingContent()
            }
        }
    }
    } // Column
}

/**
 * 横向列表中心带跟焦（与纵向网格同策略，主轴为水平）。
 *
 * - 获焦项在中线左侧且完整可见：尽量不滚；首屏左半区保持静止，左缘不被拽走。
 * - 向右越过中线 / 向左相对中线偏左且已有滚动：按差值 scrollBy 把项中心拉回中线。
 * - 左/右被裁：只滚裁切量；未布局时先滚近再微调。
 *
 * 禁止对每个获焦项 animateScrollToItem 无 offset（会把项钉在 firstVisible 左缘）。
 */
private suspend fun LazyListState.scrollFocusedItemWithCenterBand(index: Int) {
    var target = layoutInfo.visibleItemsInfo.firstOrNull { info -> info.index == index }
    if (target == null) {
        // 尚未进入布局：先滚进可见范围，再交给中心带逻辑。
        animateScrollToItem(index)
        target = layoutInfo.visibleItemsInfo.firstOrNull { info -> info.index == index }
            ?: return
    }
    val layoutInfo = layoutInfo
    val viewportStart = layoutInfo.viewportStartOffset
    val viewportEnd = layoutInfo.viewportEndOffset
    val viewportSize = (viewportEnd - viewportStart).coerceAtLeast(1)
    val centerLine = viewportStart + viewportSize / 2
    // LazyListItemInfo：主轴 offset / size 为 Int。
    val itemStart = target.offset
    val itemSize = target.size
    val itemEnd = itemStart + itemSize
    val itemCenter = itemStart + itemSize / 2
    val edgeSafePx = 8
    when {
        // 左缘被裁：刚好露出，不要 pin 成 firstVisible。
        itemStart < viewportStart + edgeSafePx -> {
            val delta = (itemStart - (viewportStart + edgeSafePx)).toFloat()
            if (abs(delta) > 1f) {
                animateScrollBy(delta)
            }
        }
        // 右缘被裁：刚好露出。
        itemEnd > viewportEnd - edgeSafePx -> {
            val delta = (itemEnd - (viewportEnd - edgeSafePx)).toFloat()
            if (delta > 1f) {
                animateScrollBy(delta)
            }
        }
        // 向右越过中线：跟滚，列表被焦点带走。
        itemCenter > centerLine -> {
            val delta = (itemCenter - centerLine).toFloat()
            if (delta > 1f) {
                animateScrollBy(delta)
            }
        }
        // 向左相对中线偏左：回拉到中线（首屏 offset≈0 时负向 scrollBy 无效果，左缘不被动）。
        itemCenter < centerLine -> {
            val delta = (itemCenter - centerLine).toFloat()
            if (delta < -1f) {
                animateScrollBy(delta)
            }
        }
    }
}
