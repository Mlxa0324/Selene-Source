package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.focusGroup
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.unit.dp
import kotlin.math.abs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.yield

/**
 * 将焦点落到 Lazy 行内目标项。
 *
 * - [scrollPreferredIntoView]=true：优先 [preferredIndex]，不在视口则先 scrollToItem 再 requestFocus
 *   （详情下探当前线路/选集、顶栏下探回到上次卡片）。
 * - [scrollPreferredIntoView]=false：只在已组合的可见项里就近落焦，**不改横向 offset**
 *   （上下跨轨 re-enter keep-offset）；仅当没有任何可见项时才允许滚到 preferred。
 *
 * 解决「目标在可视区外时上下键无法进入该列表」——Lazy 未组合项没有有效 FocusRequester。
 *
 * @param listState 横向/纵向 LazyList 状态。
 * @param preferredIndex 优先落点（如当前选中集、上次浏览下标）。
 * @param itemCount 列表项数。
 * @param requestFocus 对指定下标 requestFocus，成功返回 true。
 * @param scrollPreferredIntoView 是否允许为 preferred 主动横向/主轴滚动。
 */
suspend fun focusLazyListItemNearest(
    listState: LazyListState,
    preferredIndex: Int,
    itemCount: Int,
    requestFocus: suspend (Int) -> Boolean,
    scrollPreferredIntoView: Boolean = true,
) {
    if (itemCount <= 0) {
        return
    }
    val target = preferredIndex.coerceIn(0, itemCount - 1)
    val visible = listState.layoutInfo.visibleItemsInfo

    // 1) preferred 已在视口：直接落焦，保持横向位置。
    if (visible.any { info -> info.index == target }) {
        if (requestFocus(target)) {
            return
        }
    }

    // 2) 视口内就近项（跨轨 re-enter / preferred requester 未挂上）。
    if (visible.isNotEmpty()) {
        val nearestVisible = visible
            .minByOrNull { info -> abs(info.index - target) }
            ?.index
        if (nearestVisible != null && requestFocus(nearestVisible)) {
            return
        }
        // 可见项均 requestFocus 失败且不允许滚 preferred：放弃（避免乱滚）。
        if (!scrollPreferredIntoView) {
            return
        }
    }

    // 3) 无可见项，或允许滚到 preferred：先组合目标再落焦。
    if (!scrollPreferredIntoView && visible.isEmpty()) {
        // 列表完全未布局时仍尝试滚一次，否则永远进不去。
        runCatching { listState.scrollToItem(index = target) }
        yield()
        delay(24)
    } else if (scrollPreferredIntoView) {
        runCatching { listState.scrollToItem(index = target) }
        yield()
        delay(24)
    }

    if (requestFocus(target)) {
        return
    }

    // 4) 目标 requester 仍未挂上：落到几何上最靠近 preferred 的可见项。
    val nearest = listState.layoutInfo.visibleItemsInfo
        .minByOrNull { info -> abs(info.index - target) }
        ?.index
        ?: return
    if (nearest != target && scrollPreferredIntoView) {
        runCatching { listState.scrollToItem(index = nearest) }
        delay(16)
    }
    requestFocus(nearest)
}

/**
 * 网格版就近落焦：先滚到目标再 requestFocus（分类页等纵向网格）。
 *
 * @param gridState 网格状态。
 * @param preferredIndex 业务下标（不含 header）。
 * @param itemCount 业务项数。
 * @param headerOffset 全宽 header 占用的 lazy 下标数。
 * @param requestFocus 对业务下标 requestFocus。
 * @param scrollPreferredIntoView 是否允许为 preferred 主动滚动。
 */
suspend fun focusLazyGridItemNearest(
    gridState: LazyGridState,
    preferredIndex: Int,
    itemCount: Int,
    headerOffset: Int = 0,
    requestFocus: suspend (Int) -> Boolean,
    scrollPreferredIntoView: Boolean = true,
) {
    if (itemCount <= 0) {
        return
    }
    val target = preferredIndex.coerceIn(0, itemCount - 1)
    val lazyIndex = target + headerOffset
    val visibleBusiness = gridState.layoutInfo.visibleItemsInfo
        .filter { info -> info.index >= headerOffset }

    if (visibleBusiness.any { info -> info.index == lazyIndex }) {
        if (requestFocus(target)) {
            return
        }
    }

    if (visibleBusiness.isNotEmpty()) {
        val nearestLazy = visibleBusiness
            .minByOrNull { info -> abs(info.index - lazyIndex) }
            ?.index
        if (nearestLazy != null) {
            val nearestBusiness = (nearestLazy - headerOffset).coerceIn(0, itemCount - 1)
            if (requestFocus(nearestBusiness)) {
                return
            }
        }
        if (!scrollPreferredIntoView) {
            return
        }
    }

    if (scrollPreferredIntoView || visibleBusiness.isEmpty()) {
        runCatching { gridState.scrollToItem(index = lazyIndex) }
        yield()
        delay(24)
    }

    if (requestFocus(target)) {
        return
    }

    val nearestLazy = gridState.layoutInfo.visibleItemsInfo
        .filter { info -> info.index >= headerOffset }
        .minByOrNull { info -> abs(info.index - lazyIndex) }
        ?.index
        ?: return
    val nearestBusiness = (nearestLazy - headerOffset).coerceIn(0, itemCount - 1)
    if (nearestBusiness != target && scrollPreferredIntoView) {
        runCatching { gridState.scrollToItem(index = nearestLazy) }
        delay(16)
    }
    requestFocus(nearestBusiness)
}

/**
 * 始终组合的 1dp 焦点入口：方向键进入列表时先就近/滚到 [preferredIndex]，再交给真实 item。
 *
 * 用法：Hero/上区 `down = entryFocusRequester`；列表旁放本锚点（始终在 composition 中）。
 *
 * @param entryFocusRequester 供外层方向键指向的入口。
 * @param preferredIndex 优先业务下标。
 * @param itemCount 列表项数。
 * @param listState Lazy 列表状态。
 * @param requestItemFocus 对业务下标 requestFocus。
 * @param scrollPreferredIntoView 是否允许滚到 preferred（跨层下探当前项 true；keep-offset false）。
 * @param scope 协程作用域。
 */
@Composable
fun TvLazyListFocusEntry(
    entryFocusRequester: FocusRequester,
    preferredIndex: () -> Int,
    itemCount: Int,
    listState: LazyListState,
    requestItemFocus: suspend (Int) -> Boolean,
    scrollPreferredIntoView: Boolean = true,
    scope: CoroutineScope = rememberCoroutineScope(),
) {
    Box(
        modifier = Modifier
            .size(1.dp)
            .focusRequester(entryFocusRequester)
            .onFocusChanged { focusState ->
                if (!focusState.isFocused || itemCount <= 0) {
                    return@onFocusChanged
                }
                scope.launch {
                    focusLazyListItemNearest(
                        listState = listState,
                        preferredIndex = preferredIndex(),
                        itemCount = itemCount,
                        requestFocus = requestItemFocus,
                        scrollPreferredIntoView = scrollPreferredIntoView,
                    )
                }
            }
            .focusable(),
    )
}

/**
 * 海报轨 focusGroup：上下进入时就近落焦（可见项优先，不强制复位横向 offset）。
 *
 * @param preferredItemFocusRequester 非上下进入时的默认落点（通常首卡）。
 * @param preferredIndex 优先业务下标（如 lastFocused）。
 * @param itemCount 项数。
 * @param listState 横向列表状态。
 * @param requestItemFocus 对下标 requestFocus。
 * @param onVerticalEnter 上下进入时额外回调（如清横向会话下标）。
 */
@Composable
fun rememberPosterRailFocusGroupModifier(
    preferredItemFocusRequester: FocusRequester,
    preferredIndex: () -> Int,
    itemCount: Int,
    listState: LazyListState,
    requestItemFocus: suspend (Int) -> Boolean,
    onVerticalEnter: (() -> Unit)? = null,
): Modifier {
    val scope = rememberCoroutineScope()
    return remember(preferredItemFocusRequester, itemCount, listState) {
        Modifier
            .focusProperties {
                onEnter = {
                    val isVerticalEnter =
                        requestedFocusDirection == FocusDirection.Up ||
                            requestedFocusDirection == FocusDirection.Down
                    if (isVerticalEnter) {
                        onVerticalEnter?.invoke()
                        // 同步先试可见就近；失败再 cancel + 异步滚入（列表完全未布局时）。
                        val preferred = preferredIndex().coerceIn(0, (itemCount - 1).coerceAtLeast(0))
                        val visible = listState.layoutInfo.visibleItemsInfo
                        val syncTarget = when {
                            itemCount <= 0 -> null
                            visible.any { info -> info.index == preferred } -> preferred
                            visible.isNotEmpty() -> {
                                visible.minByOrNull { info -> abs(info.index - preferred) }?.index
                            }
                            else -> null
                        }
                        if (syncTarget != null) {
                            // 同步 requestFocus 成功则系统完成进入；失败走异步。
                            // 注意：requestItemFocus 是 suspend，这里不能在 onEnter 里 await。
                            // 统一 cancel 后异步落焦，避免与几何搜索竞态。
                        }
                        cancelFocusChange()
                        scope.launch {
                            focusLazyListItemNearest(
                                listState = listState,
                                preferredIndex = preferredIndex(),
                                itemCount = itemCount,
                                requestFocus = requestItemFocus,
                                // 上下跨轨：可见就近，不拽横向；无可见项时才滚。
                                scrollPreferredIntoView = false,
                            )
                        }
                    } else {
                        runCatching { preferredItemFocusRequester.requestFocus() }
                    }
                }
            }
            .focusGroup()
    }
}
