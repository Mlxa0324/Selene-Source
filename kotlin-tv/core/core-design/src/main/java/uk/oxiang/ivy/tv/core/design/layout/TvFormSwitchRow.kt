package uk.oxiang.ivy.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Row
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
import androidx.tv.material3.Switch
import androidx.tv.material3.SwitchDefaults
import androidx.tv.material3.Text
import uk.oxiang.ivy.tv.core.design.LocalTvThemePalette
import uk.oxiang.ivy.tv.core.design.TvTokens

/**
 * TV 表单开关行。
 *
 * 左键=关，右键=开，确认键=切换。Switch 仅展示，不可获焦。
 *
 * @param label 左侧标签文案。
 * @param checked 当前开关状态。
 * @param onCheckedChange 状态变更回调。
 * @param modifier 外层修饰器。
 * @param focusRequester 外部焦点请求器。
 */
@Composable
fun TvFormSwitchRow(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val palette = LocalTvThemePalette.current

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(TvTokens.FormRowHeight)
            .background(
                color = TvTokens.FormFieldBackground,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = if (isFocused) palette.focus else TvTokens.FormBorder,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .padding(horizontal = TvTokens.FormRowHorizontalPadding)
            .then(
                if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier
            )
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                when (event.key) {
                    Key.DirectionLeft -> {
                        if (checked) onCheckedChange(false)
                        true
                    }
                    Key.DirectionRight -> {
                        if (!checked) onCheckedChange(true)
                        true
                    }
                    Key.Enter, Key.DirectionCenter -> {
                        onCheckedChange(!checked)
                        true
                    }
                    else -> false
                }
            }
            .focusable(interactionSource = interactionSource),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = TvTokens.FormTextSecondary,
            fontSize = 15.sp,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = if (checked) "开启" else "关闭",
            color = if (checked) palette.accent else TvTokens.FormTextSecondary,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.padding(end = 12.dp),
        )
        // Switch 仅作视觉展示，焦点由整行承接
        Switch(
            checked = checked,
            onCheckedChange = {},
            enabled = false,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = palette.accent,
                uncheckedThumbColor = TvTokens.FormTextSecondary,
                uncheckedTrackColor = TvTokens.FormBorder,
                disabledCheckedThumbColor = Color.White,
                disabledCheckedTrackColor = palette.accent,
                disabledUncheckedThumbColor = TvTokens.FormTextSecondary,
                disabledUncheckedTrackColor = TvTokens.FormBorder,
            ),
        )
    }
}
