package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * 随内容滚动的紧凑页头（对齐电影 Tab [PosterGridHeader] 密度）。
 *
 * 网格已有左右 contentPadding，本组件不再叠加水平缩进。
 *
 * @param title 主标题。
 * @param subtitle 副标题；空则不展示。
 * @param trailing 标题行右侧操作（如「删除全部」）。
 * @param modifier 外层修饰器。
 */
@Composable
fun TvScrollablePageHeader(
    title: String,
    subtitle: String? = null,
    trailing: (@Composable () -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge.copy(
                    fontSize = 22.sp,
                    fontWeight = FontWeight.ExtraBold,
                ),
                color = TvTokens.TextPrimary,
            )
            if (!subtitle.isNullOrBlank()) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp),
                    color = TvTokens.TextSecondary,
                )
            }
        }
        if (trailing != null) {
            Box(modifier = Modifier.padding(start = 16.dp)) {
                trailing()
            }
        }
    }
}

/**
 * 页头右侧小操作按钮（如「删除全部」）。
 *
 * @param label 按钮文案。
 * @param onClick 确认回调。
 * @param modifier 外层修饰器。
 * @param focusRequester 可选焦点请求器。
 * @param onArrowDown 下键回调（回到网格）。
 */
@Composable
fun TvHeaderActionButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester? = null,
    onArrowDown: (() -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(10.dp)
    Box(
        modifier = modifier
            .testTag("tv-header-action-button")
            .then(if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier)
            .background(
                color = if (isFocused) TvTokens.Accent else TvTokens.Surface,
                shape = shape,
            )
            .border(
                width = 2.dp,
                color = if (isFocused) Color.White else TvTokens.Outline.copy(alpha = 0.45f),
                shape = shape,
            )
            .focusable(interactionSource = interactionSource)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            )
            .onPreviewKeyEvent { event ->
                if (
                    event.key == Key.Enter ||
                    event.key == Key.DirectionCenter ||
                    event.key == Key.NumPadEnter ||
                    event.key == Key.Spacebar
                ) {
                    if (event.type == KeyEventType.KeyUp) {
                        onClick()
                    }
                    return@onPreviewKeyEvent true
                }
                if (
                    event.type == KeyEventType.KeyDown &&
                    event.key == Key.DirectionDown &&
                    onArrowDown != null
                ) {
                    onArrowDown()
                    return@onPreviewKeyEvent true
                }
                false
            }
            .padding(horizontal = 18.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}
