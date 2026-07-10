package uk.oxiang.ivy.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Button
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import uk.oxiang.ivy.tv.core.design.LocalTvThemePalette
import uk.oxiang.ivy.tv.core.design.TvTokens

/**
 * TV 页面状态面板类型。
 */
enum class TvStatePanelKind {
    /**
     * 空数据状态。
     */
    Empty,

    /**
     * 加载中状态。
     */
    Loading,

    /**
     * 错误状态。
     */
    Error,
}

/**
 * TV 通用状态面板。
 *
 * @param kind 状态类型。
 * @param title 状态标题。
 * @param message 状态说明。
 * @param actionLabel 主按钮文案。
 * @param onAction 主按钮回调。
 * @param contentFocusRequester 顶部导航下探时使用的内容焦点请求器。
 * @param modifier 外层修饰器。
 */
@Composable
fun TvStatePanel(
    kind: TvStatePanelKind,
    title: String,
    message: String,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    contentFocusRequester: FocusRequester? = null,
    modifier: Modifier = Modifier,
) {
    val palette = LocalTvThemePalette.current
    val borderColor = when (kind) {
        TvStatePanelKind.Empty -> TvTokens.Outline
        TvStatePanelKind.Loading -> palette.focus.copy(alpha = 0.45f)
        TvStatePanelKind.Error -> TvTokens.Danger.copy(alpha = 0.7f)
    }
    val hasAction = !actionLabel.isNullOrBlank() && onAction != null
    val panelFocusModifier = if (!hasAction && contentFocusRequester != null) {
        // 加载和空态没有按钮时，面板自身承接顶部导航下方向焦点。
        Modifier.focusRequester(contentFocusRequester).focusable()
    } else {
        Modifier
    }
    val actionFocusModifier = if (hasAction && contentFocusRequester != null) {
        // 错误态有按钮时，焦点直接落到可确认的操作按钮上。
        Modifier.focusRequester(contentFocusRequester)
    } else {
        Modifier
    }

    Box(modifier = modifier) {
        Column(
            modifier = panelFocusModifier
                .background(
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    shape = RoundedCornerShape(TvTokens.CardRadius),
                )
                .border(
                    width = 1.dp,
                    color = borderColor,
                    shape = RoundedCornerShape(TvTokens.CardRadius),
                )
                .padding(horizontal = 28.dp, vertical = 24.dp),
            horizontalAlignment = Alignment.Start,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
                color = TvTokens.TextPrimary,
            )
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            if (hasAction) {
                Button(
                    modifier = actionFocusModifier,
                    onClick = onAction ?: {},
                ) {
                    Text(text = actionLabel ?: "")
                }
            }
        }
    }
}
