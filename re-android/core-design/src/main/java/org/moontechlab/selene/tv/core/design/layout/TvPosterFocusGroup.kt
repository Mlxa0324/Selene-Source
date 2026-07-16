package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.focusGroup
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import kotlinx.coroutines.launch

/**
 * 构建海报列表焦点分组修饰器。
 *
 * 上下跨轨进入：优先在已组合可见项中就近落焦；若列表项均未布局则滚到 [preferredIndex]
 * 再落焦，避免「目标不在可视区就整轨进不去」。
 *
 * 非上下进入（如程序 requestFocus 到分组）：落到 [firstCardFocusRequester]。
 *
 * @param firstCardFocusRequester 首张真实海报的焦点请求器。
 * @param onVerticalEnter 上下方向进入分组时的回调；用于清理同轨会话状态，避免横向列表被误推进。
 * @param listState 可选横向 Lazy 状态；与 [requestItemFocus] 同时提供时启用就近落焦。
 * @param preferredIndex 优先业务下标（通常 lastFocused）。
 * @param itemCount 业务项数。
 * @param requestItemFocus 对业务下标 requestFocus。
 * @return 已绑定可选焦点请求器的焦点分组修饰器。
 */
internal fun Modifier.posterFocusGroup(
    firstCardFocusRequester: FocusRequester,
    onVerticalEnter: (() -> Unit)? = null,
    listState: LazyListState? = null,
    preferredIndex: (() -> Int)? = null,
    itemCount: Int = 0,
    requestItemFocus: (suspend (Int) -> Boolean)? = null,
): Modifier {
    return composed {
        val scope = rememberCoroutineScope()
        focusProperties {
            onEnter = {
                val isVerticalEnter =
                    requestedFocusDirection == FocusDirection.Up ||
                        requestedFocusDirection == FocusDirection.Down
                if (isVerticalEnter) {
                    // 标记本次为跨轨进入，后续卡片获焦不再按左右步进推横向列表。
                    onVerticalEnter?.invoke()
                    val state = listState
                    val prefer = preferredIndex
                    val request = requestItemFocus
                    if (state != null && prefer != null && request != null && itemCount > 0) {
                        // 接管默认几何搜索：避免系统去 request 未组合项失败后焦点卡住。
                        cancelFocusChange()
                        scope.launch {
                            focusLazyListItemNearest(
                                listState = state,
                                preferredIndex = prefer(),
                                itemCount = itemCount,
                                requestFocus = request,
                                // 上下 re-enter：可见就近，保持横向 offset。
                                scrollPreferredIntoView = false,
                            )
                        }
                    }
                    // 未提供 listState 时保持旧行为：交给系统几何就近。
                } else {
                    // 首次进入或其他方向仍落到首张真实海报，保证入口可见可确认。
                    runCatching { firstCardFocusRequester.requestFocus() }
                }
            }
        }
            .focusGroup()
    }
}

/**
 * 网格焦点分组：上下进入时就近落焦（含视口外目标先 scroll 再 request）。
 *
 * @param firstCardFocusRequester 首卡 requester。
 * @param gridState 网格状态。
 * @param preferredIndex 优先业务下标。
 * @param itemCount 业务项数。
 * @param headerOffset header 占用的 lazy 下标。
 * @param requestItemFocus 对业务下标 requestFocus。
 * @param onVerticalEnter 上下进入回调。
 */
internal fun Modifier.posterGridFocusGroup(
    firstCardFocusRequester: FocusRequester,
    gridState: LazyGridState,
    preferredIndex: () -> Int,
    itemCount: Int,
    headerOffset: Int = 0,
    requestItemFocus: suspend (Int) -> Boolean,
    onVerticalEnter: (() -> Unit)? = null,
): Modifier {
    return composed {
        val scope = rememberCoroutineScope()
        focusProperties {
            onEnter = {
                val isVerticalEnter =
                    requestedFocusDirection == FocusDirection.Up ||
                        requestedFocusDirection == FocusDirection.Down
                if (isVerticalEnter) {
                    onVerticalEnter?.invoke()
                    if (itemCount > 0) {
                        cancelFocusChange()
                        scope.launch {
                            focusLazyGridItemNearest(
                                gridState = gridState,
                                preferredIndex = preferredIndex(),
                                itemCount = itemCount,
                                headerOffset = headerOffset,
                                requestFocus = requestItemFocus,
                                // 网格纵向：允许滚到 preferred（同列邻居可能未组合）。
                                scrollPreferredIntoView = true,
                            )
                        }
                    }
                } else {
                    runCatching { firstCardFocusRequester.requestFocus() }
                }
            }
        }
            .focusGroup()
    }
}
