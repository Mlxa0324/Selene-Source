package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.ui.draw.clip
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

/**
 * TV 表单滑杆行。
 *
 * 左键=-step，右键=+step。Slider 仅展示，不可获焦。
 *
 * @param label 左侧标签文案。
 * @param value 当前值。
 * @param onValueChange 值变更回调。
 * @param valueRange 取值范围。
 * @param step 步进值。
 * @param valueDisplay 值显示文案。
 * @param modifier 外层修饰器。
 * @param focusRequester 外部焦点请求器。
 * @param onArrowUp 上键自定义焦点回调。
 * @param onArrowDown 下键自定义焦点回调。
 */
@Composable
fun TvFormSliderRow(
    label: String,
    value: Float,
    onValueChange: (Float) -> Unit,
    valueRange: ClosedFloatingPointRange<Float> = 0f..1f,
    step: Float = 0.1f,
    valueDisplay: (Float) -> String = { "%.0f%%".format(it * 100) },
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester? = null,
    onArrowUp: (() -> Unit)? = null,
    onArrowDown: (() -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = TvTokens.FormFieldBackground,
                shape = RoundedCornerShape(TvTokens.FormFieldRadius),
            )
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = if (isFocused) TvTokens.FocusBorder else TvTokens.FormBorder,
                shape = RoundedCornerShape(TvTokens.FormFieldRadius),
            )
            .padding(
                horizontal = TvTokens.FormRowHorizontalPadding,
                vertical = 12.dp,
            )
            .then(
                if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier
            )
            .onPreviewKeyEvent { event ->
                // 自定义上下链优先，左右键继续调值。
                if (event.key == Key.DirectionUp && onArrowUp != null) {
                    if (event.type == KeyEventType.KeyDown) onArrowUp.invoke()
                    return@onPreviewKeyEvent true
                }
                if (event.key == Key.DirectionDown && onArrowDown != null) {
                    if (event.type == KeyEventType.KeyDown) onArrowDown.invoke()
                    return@onPreviewKeyEvent true
                }
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                when (event.key) {
                    Key.DirectionLeft -> {
                        val newValue = (value - step).coerceIn(valueRange)
                        onValueChange(newValue)
                        true
                    }
                    Key.DirectionRight -> {
                        val newValue = (value + step).coerceIn(valueRange)
                        onValueChange(newValue)
                        true
                    }
                    else -> false
                }
            }
            .focusable(interactionSource = interactionSource),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            androidx.tv.material3.Text(
                text = label,
                color = TvTokens.FormTextSecondary,
                fontSize = 15.sp,
                modifier = Modifier.weight(1f),
            )
            androidx.tv.material3.Text(
                text = valueDisplay(value),
                color = TvTokens.TextPrimary,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
            )
        }
        // 自定义视觉滑杆（不可获焦，仅展示）
        val fraction = ((value - valueRange.start) / (valueRange.endInclusive - valueRange.start)).coerceIn(0f, 1f)
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(TvTokens.FormBorder),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(fraction)
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(TvTokens.Accent),
            )
        }
    }
}
