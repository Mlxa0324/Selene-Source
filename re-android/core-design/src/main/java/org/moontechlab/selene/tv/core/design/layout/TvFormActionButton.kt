package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.handleTvConfirmKeyUp
import org.moontechlab.selene.tv.core.design.focus.tvPointerClickable

/**
 * TV 表单主题色操作按钮。
 *
 * @param label 按钮文案。
 * @param onClick 点击回调。
 * @param modifier 外层修饰器。
 * @param focusRequester 外部焦点请求器。
 * @param accentColor 按钮主题色，默认使用 [TvTokens.Accent]。
 * @param filled 是否始终实心填充（登录等主 CTA）；false 时未获焦半透明、获焦实心。
 * @param onArrowUp 上键自定义焦点回调。
 * @param onArrowDown 下键自定义焦点回调。
 */
@Composable
fun TvFormActionButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester? = null,
    accentColor: Color = TvTokens.Accent,
    filled: Boolean = false,
    onArrowUp: (() -> Unit)? = null,
    onArrowDown: (() -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(TvTokens.FormFieldRadius)
    val background = when {
        filled && isFocused -> accentColor
        filled -> accentColor.copy(alpha = 0.92f)
        isFocused -> accentColor
        else -> accentColor.copy(alpha = 0.16f)
    }
    val borderColor = when {
        isFocused -> TvTokens.FocusBorder
        filled -> accentColor.copy(alpha = 0.55f)
        else -> Color.Transparent
    }
    val textColor = when {
        filled || isFocused -> Color.White
        else -> accentColor
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(50.dp)
            .background(
                color = background,
                shape = shape,
            )
            .border(
                width = if (isFocused || filled) 2.dp else 0.dp,
                color = borderColor,
                shape = shape,
            )
            .then(
                if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier
            )
            .onPreviewKeyEvent { event ->
                if (event.key == Key.DirectionUp && onArrowUp != null) {
                    if (event.type == KeyEventType.KeyDown) onArrowUp.invoke()
                    return@onPreviewKeyEvent true
                }
                if (event.key == Key.DirectionDown && onArrowDown != null) {
                    if (event.type == KeyEventType.KeyDown) onArrowDown.invoke()
                    return@onPreviewKeyEvent true
                }
                // 空格 / Enter / 方向中心键都确认点击。
                handleTvConfirmKeyUp(event, onConfirm = onClick)
            }
            // 平板鼠标左键点击与确认键等价。
            .tvPointerClickable(onClick = onClick)
            .focusable(interactionSource = interactionSource)
            .padding(horizontal = 24.dp),
        contentAlignment = Alignment.Center,
    ) {
        androidx.tv.material3.Text(
            text = label,
            color = textColor,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}
