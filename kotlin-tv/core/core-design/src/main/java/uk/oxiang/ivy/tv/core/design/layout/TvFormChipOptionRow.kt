package uk.oxiang.ivy.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
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
 * TV 表单 Chip 选项行 —— 横向 chip 排列，支持焦点记忆。
 *
 * 焦点离开再返回时自动恢复最后获焦的 chip。
 *
 * @param T 选项数据类型。
 * @param label 左侧标签文案。
 * @param options 可选项列表。
 * @param selectedKey 当前选中项。
 * @param optionLabel 选项显示文案。
 * @param onOptionSelected 选中回调。
 * @param modifier 外层修饰器。
 * @param onFocusEntryChanged 获焦入口变更回调，父组件据此决定进入该行时定位哪个 chip。
 * @param chipPreview 可选 chip 预览（颜色块/图标等），默认仅文字。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun <T> TvFormChipOptionRow(
    label: String,
    options: List<T>,
    selectedKey: T,
    optionLabel: (T) -> String,
    onOptionSelected: (T) -> Unit,
    modifier: Modifier = Modifier,
    onFocusEntryChanged: ((FocusRequester) -> Unit)? = null,
    chipPreview: @Composable (T, Boolean) -> Unit = { _, _ -> },
) {
    val palette = LocalTvThemePalette.current
    val selectedIndex = options.indexOfFirst { it == selectedKey }.coerceAtLeast(0)
    val chipFocusRequesters = remember(options.size) {
        List(options.size) { FocusRequester() }
    }
    var lastFocusedIndex by remember { mutableIntStateOf(selectedIndex) }

    // 首次进入时立即上报入口焦点，确保父组件下键能正确定位
    LaunchedEffect(Unit) {
        onFocusEntryChanged?.invoke(chipFocusRequesters[selectedIndex])
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = TvTokens.FormTextSecondary,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.padding(end = 16.dp),
        )

        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            options.forEachIndexed { index, option ->
                val isSelected = option == selectedKey
                val interactionSource = remember { MutableInteractionSource() }
                val isFocused by interactionSource.collectIsFocusedAsState()

                val chipBg = when {
                    isSelected -> palette.accent
                    isFocused -> palette.focusFill
                    else -> TvTokens.FormFieldBackground
                }
                val chipBorder = when {
                    isFocused -> palette.focus
                    isSelected -> palette.accent
                    else -> TvTokens.FormBorder
                }

                Box(
                    modifier = Modifier
                        .height(40.dp)
                        .background(
                            color = chipBg,
                            shape = RoundedCornerShape(TvTokens.CardRadius),
                        )
                        .border(
                            width = if (isFocused) 2.dp else 1.dp,
                            color = chipBorder,
                            shape = RoundedCornerShape(TvTokens.CardRadius),
                        )
                        .focusRequester(chipFocusRequesters[index])
                        .onPreviewKeyEvent { event ->
                            if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                            when (event.key) {
                                Key.Enter, Key.DirectionCenter -> {
                                    onOptionSelected(option)
                                    true
                                }
                                else -> false
                            }
                        }
                        .onFocusChanged { focusState ->
                            if (focusState.isFocused) {
                                lastFocusedIndex = index
                                onFocusEntryChanged?.invoke(chipFocusRequesters[index])
                            }
                        }
                        .focusable(interactionSource = interactionSource)
                        .padding(horizontal = 16.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        chipPreview(option, isSelected)
                        Text(
                            text = optionLabel(option),
                            color = if (isSelected) Color.White else TvTokens.TextPrimary,
                            fontSize = 14.sp,
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                        )
                    }
                }
            }
        }
    }
}
