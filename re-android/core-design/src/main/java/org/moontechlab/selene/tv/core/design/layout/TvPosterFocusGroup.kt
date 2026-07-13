package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.focusGroup
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusDirection
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties

/**
 * 构建海报列表焦点分组修饰器。
 *
 * @param firstCardFocusRequester 首张真实海报的焦点请求器。
 * @param onVerticalEnter 上下方向进入分组时的回调；用于清理同轨会话状态，避免横向列表被误推进。
 * @return 已绑定可选焦点请求器的焦点分组修饰器。
 */
internal fun Modifier.posterFocusGroup(
    firstCardFocusRequester: FocusRequester,
    onVerticalEnter: (() -> Unit)? = null,
): Modifier {
    return focusProperties {
            onEnter = {
                // 上下跨轨进入交给系统几何就近，避免强行跳到首卡并带动横向列表复位。
                val isVerticalEnter =
                    requestedFocusDirection == FocusDirection.Up ||
                        requestedFocusDirection == FocusDirection.Down
                if (isVerticalEnter) {
                    // 标记本次为跨轨进入，后续卡片获焦不再按左右步进推横向列表。
                    onVerticalEnter?.invoke()
                } else {
                    // 首次进入或其他方向仍落到首张真实海报，保证入口可见可确认。
                    runCatching { firstCardFocusRequester.requestFocus() }
                }
            }
        }
        .focusGroup()
}
