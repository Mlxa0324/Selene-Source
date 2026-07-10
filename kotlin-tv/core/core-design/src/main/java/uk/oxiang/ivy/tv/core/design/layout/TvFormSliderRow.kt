package uk.oxiang.ivy.tv.core.design.layout

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
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val palette = LocalTvThemePalette.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                color = TvTokens.FormFieldBackground,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = if (isFocused) palette.focus else TvTokens.FormBorder,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .padding(
                horizontal = TvTokens.FormRowHorizontalPadding,
                vertical = 12.dp,
            )
            .then(
                if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier
            )
            .onPreviewKeyEvent { event ->
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
            Text(
                text = label,
                color = TvTokens.FormTextSecondary,
                fontSize = 15.sp,
                modifier = Modifier.weight(1f),
            )
            Text(
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
                    .background(palette.accent),
            )
        }
    }
}
