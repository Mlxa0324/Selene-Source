package org.moontechlab.selene.tv.core.design.layout

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
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
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.handleTvConfirmKeyUp
import org.moontechlab.selene.tv.core.design.focus.isTvConfirmKey
import org.moontechlab.selene.tv.core.design.focus.tvPointerClickable

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
 * @param entryFocusRequester 外部入口焦点请求器；请求它时会落到最近选中/记忆 chip。
 * @param onArrowUp 上键自定义焦点回调。
 * @param onArrowDown 下键自定义焦点回调。
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
    entryFocusRequester: FocusRequester? = null,
    onArrowUp: (() -> Unit)? = null,
    onArrowDown: (() -> Unit)? = null,
    chipPreview: @Composable (T, Boolean) -> Unit = { _, _ -> },
) {
    val selectedIndex = options.indexOfFirst { it == selectedKey }.coerceAtLeast(0)
    val chipFocusRequesters = remember(options.size) {
        List(options.size) { FocusRequester() }
    }
    var lastFocusedIndex by remember { mutableIntStateOf(selectedIndex) }

    // 首次进入时立即上报入口焦点，确保父组件下键能正确定位
    LaunchedEffect(Unit) {
        onFocusEntryChanged?.invoke(chipFocusRequesters[selectedIndex])
    }

    // 外部入口焦点：请求后落到最近记忆/选中 chip，便于上下链稳定进出。
    if (entryFocusRequester != null) {
        LaunchedEffect(entryFocusRequester, options.size, selectedIndex) {
            // 无操作，仅声明依赖；真正转发在 focusProperties 入口锚点完成。
        }
    }

    // 入口锚点：外部 requestFocus 落到本行最近 chip。
    if (entryFocusRequester != null) {
        androidx.compose.foundation.layout.Box(
            modifier = Modifier
                .size(1.dp)
                .focusRequester(entryFocusRequester)
                .onFocusChanged { state ->
                    if (state.isFocused) {
                        val target = chipFocusRequesters.getOrNull(lastFocusedIndex)
                            ?: chipFocusRequesters.getOrNull(selectedIndex)
                        target?.requestFocus()
                    }
                }
                .focusable(),
        )
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.tv.material3.Text(
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
                    isSelected -> TvTokens.Accent
                    isFocused -> TvTokens.FocusFill
                    else -> TvTokens.FormFieldBackground
                }
                val chipBorder = when {
                    isFocused -> TvTokens.FocusBorder
                    isSelected -> TvTokens.Accent
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
                            // 上下键交给宿主线性链，左右仍走系统/相邻 chip。
                            if (event.key == Key.DirectionUp && onArrowUp != null) {
                                if (event.type == KeyEventType.KeyDown) onArrowUp.invoke()
                                return@onPreviewKeyEvent true
                            }
                            if (event.key == Key.DirectionDown && onArrowDown != null) {
                                if (event.type == KeyEventType.KeyDown) onArrowDown.invoke()
                                return@onPreviewKeyEvent true
                            }
                            // 空格 / Enter / 方向中心键选中 chip。
                            handleTvConfirmKeyUp(event) {
                                onOptionSelected(option)
                            }
                        }
                        .onFocusChanged { focusState ->
                            if (focusState.isFocused) {
                                lastFocusedIndex = index
                                onFocusEntryChanged?.invoke(chipFocusRequesters[index])
                            }
                        }
                        .tvPointerClickable(onClick = { onOptionSelected(option) })
                        .focusable(interactionSource = interactionSource)
                        .padding(horizontal = 16.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        chipPreview(option, isSelected)
                        androidx.tv.material3.Text(
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
