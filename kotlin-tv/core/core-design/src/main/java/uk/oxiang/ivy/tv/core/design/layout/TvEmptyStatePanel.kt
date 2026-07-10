package uk.oxiang.ivy.tv.core.design.layout

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester

/**
 * TV 空状态面板。
 *
 * @param title 空状态标题。
 * @param message 空状态说明。
 * @param actionLabel 主按钮文案。
 * @param onAction 主按钮回调。
 * @param contentFocusRequester 顶部导航下探时使用的内容焦点请求器。
 * @param modifier 外层修饰器。
 */
@Composable
fun TvEmptyStatePanel(
    title: String,
    message: String,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    contentFocusRequester: FocusRequester? = null,
    modifier: Modifier = Modifier,
) {
    TvStatePanel(
        kind = TvStatePanelKind.Empty,
        title = title,
        message = message,
        actionLabel = actionLabel,
        onAction = onAction,
        contentFocusRequester = contentFocusRequester,
        modifier = modifier,
    )
}
