package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 表单文本输入行 —— 浏览/编辑双模式。
 *
 * 浏览态显示当前值 + "按确认编辑"提示；确认键进入编辑态，
 * 编辑态中 Enter 确认、Back 取消。
 *
 * @param label 左侧标签文案。
 * @param value 当前文本值。
 * @param onValueChange 值变更回调（仅确认时触发）。
 * @param modifier 外层修饰器。
 * @param focusRequester 外部焦点请求器，用于浏览态。
 * @param onArrowUp 上键回调。
 * @param onArrowDown 下键回调。
 * @param enabled 是否可用。
 */
@Composable
fun TvFormTextField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier,
    focusRequester: FocusRequester? = null,
    onArrowUp: (() -> Unit)? = null,
    onArrowDown: (() -> Unit)? = null,
    enabled: Boolean = true,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    var isEditing by remember { mutableStateOf(false) }
    var editText by remember { mutableStateOf(value) }
    val textFieldFocusRequester = remember { FocusRequester() }

    val borderColor = when {
        isEditing -> TvTokens.Accent
        isFocused -> TvTokens.FocusBorder
        else -> TvTokens.FormBorder
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(TvTokens.FormRowHeight)
            .background(
                color = TvTokens.FormFieldBackground,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .border(
                width = if (isFocused || isEditing) 2.dp else 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(TvTokens.CardRadius),
            )
            .padding(horizontal = TvTokens.FormRowHorizontalPadding)
            .then(
                if (focusRequester != null) Modifier.focusRequester(focusRequester) else Modifier
            )
            .onPreviewKeyEvent { event ->
                if (!enabled) return@onPreviewKeyEvent false
                // 浏览态: UP/DOWN 在 KeyDown 即消费，阻止 Compose 空间导航"跳行"
                if (!isEditing && (event.key == Key.DirectionUp || event.key == Key.DirectionDown)) {
                    if (event.type == KeyEventType.KeyUp) return@onPreviewKeyEvent true
                    if (event.key == Key.DirectionUp) onArrowUp?.invoke() else onArrowDown?.invoke()
                    return@onPreviewKeyEvent true
                }
                // 编辑态: Back 在 KeyDown 消费
                if (isEditing && event.key == Key.Back) {
                    if (event.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                    editText = value
                    isEditing = false
                    return@onPreviewKeyEvent true
                }
                // 其余键保持 KeyUp 处理
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                when {
                    isEditing && (event.key == Key.Enter || event.key == Key.DirectionCenter) -> {
                        onValueChange(editText)
                        isEditing = false
                        true
                    }
                    !isEditing && (event.key == Key.Enter || event.key == Key.DirectionCenter) -> {
                        editText = value
                        isEditing = true
                        true
                    }
                    else -> false
                }
            }
            .focusable(
                enabled = enabled && !isEditing,
                interactionSource = interactionSource,
            ),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (isEditing) {
            BasicTextField(
                value = editText,
                onValueChange = { editText = it },
                modifier = Modifier
                    .weight(1f)
                    .focusRequester(textFieldFocusRequester)
                    .onFocusChanged { state ->
                        if (state.isFocused) {
                            // 编辑态获得焦点后可由 IME 输入。
                        }
                    },
                textStyle = TextStyle(
                    color = TvTokens.TextPrimary,
                    fontSize = 16.sp,
                ),
                cursorBrush = SolidColor(TvTokens.Accent),
                singleLine = true,
                decorationBox = { innerTextField ->
                    Box {
                        if (editText.isEmpty()) {
                            androidx.tv.material3.Text(
                                text = label,
                                color = TvTokens.FormTextSecondary,
                                fontSize = 16.sp,
                            )
                        }
                        innerTextField()
                    }
                },
            )
        } else {
            // 浏览态: 标签 + 值 + 编辑提示
            androidx.tv.material3.Text(
                text = label,
                color = TvTokens.FormTextSecondary,
                fontSize = 15.sp,
                modifier = Modifier.weight(1f),
            )
            androidx.tv.material3.Text(
                text = value.ifBlank { "未填写" },
                color = if (value.isBlank()) TvTokens.FormTextSecondary else TvTokens.TextPrimary,
                fontSize = 16.sp,
            )
            if (isFocused && enabled) {
                Box(
                    modifier = Modifier
                        .padding(start = 12.dp)
                        .background(
                            color = TvTokens.Accent.copy(alpha = 0.2f),
                            shape = RoundedCornerShape(12.dp),
                        )
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                ) {
                    androidx.tv.material3.Text(
                        text = "按确认编辑",
                        color = TvTokens.Accent,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
        }
    }

    // 编辑态时自动请求焦点到输入框
    if (isEditing) {
        androidx.compose.runtime.LaunchedEffect(Unit) {
            textFieldFocusRequester.requestFocus()
        }
    }
}
