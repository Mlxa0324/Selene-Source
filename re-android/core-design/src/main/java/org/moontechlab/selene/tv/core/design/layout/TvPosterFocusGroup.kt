package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.focusGroup
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties

/**
 * 构建海报列表焦点分组修饰器。
 *
 * @param firstCardFocusRequester 首张真实海报的焦点请求器。
 * @return 已绑定可选焦点请求器的焦点分组修饰器。
 */
internal fun Modifier.posterFocusGroup(
    firstCardFocusRequester: FocusRequester,
): Modifier {
    return focusProperties {
            onEnter = {
                // 列表组获得焦点后直接转入首张真实海报，让方向键落点可见且可确认。
                runCatching { firstCardFocusRequester.requestFocus() }.getOrDefault(false)
            }
        }
        .focusGroup()
}
