package uk.oxiang.ivy.tv.core.design.layout

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
import androidx.tv.material3.Text
import uk.oxiang.ivy.tv.core.design.LocalTvThemePalette
import uk.oxiang.ivy.tv.core.design.TvTokens

/**
 * TV 表单主题色操作按钮。
 *
 * @param label 按钮文案。
 * @param onClick 点击回调。
 * @param modifier 外层修饰器。
 * @param focusRequester 外部焦点请求器。
 * @param accentColor 按钮主题色，默认读取当前 TV 主题色 [LocalTvThemePalette]。
 */
@Composable
fun TvFormActionButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester? = null,
    accentColor: Color = LocalTvThemePalette.current.accent,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val focusColor = LocalTvThemePalette.current.focus

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp)
            .background(
                color = if (isFocused) accentColor else accentColor.copy(alpha = 0.15f),
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .border(
                width = if (isFocused) 2.dp else 0.dp,
                color = if (isFocused) focusColor else Color.Transparent,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .then(
                if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier
            )
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                when (event.key) {
                    Key.Enter, Key.DirectionCenter -> {
                        onClick()
                        true
                    }
                    else -> false
                }
            }
            .focusable(interactionSource = interactionSource)
            .padding(horizontal = 24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = if (isFocused) Color.White else accentColor,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}
