package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Button
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import org.moontechlab.selene.tv.core.design.TvTokens

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
 * 空态采用居中轻量样式，避免大块灰卡贴在左上角；错误态保留操作按钮。
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

    when (kind) {
        TvStatePanelKind.Empty -> {
            // 居中轻量空态：无厚重边框卡片，适配筛选后大面积留白。
            Box(
                modifier = modifier
                    .fillMaxSize()
                    .then(panelFocusModifier)
                    .padding(horizontal = 48.dp, vertical = 32.dp),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(56.dp)
                            .background(
                                color = Color.White.copy(alpha = 0.06f),
                                shape = CircleShape,
                            )
                            .border(
                                width = 1.dp,
                                color = Color.White.copy(alpha = 0.10f),
                                shape = CircleShape,
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = "∅",
                            color = TvTokens.TextSecondary.copy(alpha = 0.85f),
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleLarge.copy(
                            fontSize = 22.sp,
                            fontWeight = FontWeight.SemiBold,
                        ),
                        color = TvTokens.TextPrimary,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodyMedium.copy(fontSize = 14.sp),
                        color = TvTokens.TextSecondary.copy(alpha = 0.88f),
                        textAlign = TextAlign.Center,
                    )
                    if (hasAction) {
                        Button(
                            modifier = actionFocusModifier.padding(top = 6.dp),
                            onClick = onAction!!,
                        ) {
                            Text(text = actionLabel!!)
                        }
                    }
                }
            }
        }

        TvStatePanelKind.Loading,
        TvStatePanelKind.Error,
        -> {
            val borderColor = when (kind) {
                TvStatePanelKind.Loading -> TvTokens.IvyGreen.copy(alpha = 0.45f)
                TvStatePanelKind.Error -> TvTokens.Danger.copy(alpha = 0.7f)
                TvStatePanelKind.Empty -> TvTokens.Outline
            }
            Box(
                modifier = modifier
                    .fillMaxSize()
                    .padding(horizontal = 48.dp, vertical = 32.dp),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    modifier = panelFocusModifier
                        .background(
                            color = TvTokens.Surface.copy(alpha = 0.92f),
                            shape = RoundedCornerShape(16.dp),
                        )
                        .border(
                            width = 1.dp,
                            color = borderColor.copy(alpha = 0.55f),
                            shape = RoundedCornerShape(16.dp),
                        )
                        .padding(horizontal = 32.dp, vertical = 28.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleLarge.copy(
                            fontWeight = FontWeight.SemiBold,
                        ),
                        color = TvTokens.TextPrimary,
                        textAlign = TextAlign.Center,
                    )
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodyMedium,
                        color = TvTokens.TextSecondary,
                        textAlign = TextAlign.Center,
                    )
                    if (hasAction) {
                        Button(
                            modifier = actionFocusModifier.padding(top = 4.dp),
                            onClick = onAction!!,
                        ) {
                            Text(text = actionLabel!!)
                        }
                    }
                }
            }
        }
    }
}
