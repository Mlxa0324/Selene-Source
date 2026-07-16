package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.Canvas
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.isTvConfirmKey
import org.moontechlab.selene.tv.core.design.focus.tvPointerClickable

/**
 * TV 表单文本输入行 —— 浏览/编辑双模式。
 *
 * 浏览态显示当前值 + "按确认编辑"提示；确认键进入编辑态。
 * 编辑态中 **确认键或返回键** 都会提交当前输入并退出编辑（避免返回丢内容），
 * 退出后焦点回到该输入行浏览态，便于继续上下移动或再次编辑。
 *
 * 密码模式 [isPassword]：浏览/编辑默认以星花掩码，右侧小眼睛可切换明文。
 *
 * @param label 左侧标签文案。
 * @param value 当前文本值。
 * @param onValueChange 值变更回调（仅确认时触发）。
 * @param modifier 外层修饰器。
 * @param focusRequester 外部焦点请求器，用于浏览态。
 * @param onArrowUp 上键回调。
 * @param onArrowDown 下键回调。
 * @param enabled 是否可用。
 * @param isPassword 是否按密码字段展示（默认星花，眼睛切换可见）。
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
    isPassword: Boolean = false,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    var isEditing by remember { mutableStateOf(false) }
    // 经历过编辑态后才在退出时回焦，避免首帧误抢焦点。
    var hasEnteredEditing by remember { mutableStateOf(false) }
    var editText by remember { mutableStateOf(value) }
    // 密码默认隐藏；明文仅在点眼睛后显示。
    var passwordVisible by remember { mutableStateOf(false) }
    val textFieldFocusRequester = remember { FocusRequester() }
    // 无外部 requester 时用本地节点承接「编辑后回焦」。
    val localBrowseFocusRequester = remember { FocusRequester() }
    val browseFocusRequester = focusRequester ?: localBrowseFocusRequester
    val eyeFocusRequester = remember { FocusRequester() }

    val borderColor = when {
        isEditing -> TvTokens.Accent
        isFocused -> TvTokens.FocusBorder
        else -> TvTokens.FormBorder
    }
    val showPlainText = !isPassword || passwordVisible
    val displayValue = when {
        value.isBlank() -> "未填写"
        showPlainText -> value
        else -> "•".repeat(value.length.coerceIn(6, 16))
    }

    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(
            modifier = Modifier
                .weight(1f)
                .height(TvTokens.FormRowHeight)
                .background(
                    color = TvTokens.FormFieldBackground,
                    shape = RoundedCornerShape(TvTokens.FormFieldRadius),
                )
                .border(
                    width = if (isFocused || isEditing) 2.dp else 1.dp,
                    color = borderColor,
                    shape = RoundedCornerShape(TvTokens.FormFieldRadius),
                )
                .padding(horizontal = TvTokens.FormRowHorizontalPadding)
                .focusRequester(browseFocusRequester)
                .onPreviewKeyEvent { event ->
                    if (!enabled) return@onPreviewKeyEvent false
                    // 浏览态：上/下交给宿主；密码行右键落到眼睛。
                    if (!isEditing) {
                        when (event.key) {
                            Key.DirectionUp -> {
                                if (onArrowUp == null) return@onPreviewKeyEvent false
                                if (event.type == KeyEventType.KeyUp) return@onPreviewKeyEvent true
                                onArrowUp.invoke()
                                return@onPreviewKeyEvent true
                            }
                            Key.DirectionDown -> {
                                if (onArrowDown == null) return@onPreviewKeyEvent false
                                if (event.type == KeyEventType.KeyUp) return@onPreviewKeyEvent true
                                onArrowDown.invoke()
                                return@onPreviewKeyEvent true
                            }
                            Key.DirectionRight -> {
                                if (!isPassword) return@onPreviewKeyEvent false
                                if (event.type == KeyEventType.KeyUp) return@onPreviewKeyEvent true
                                runCatching { eyeFocusRequester.requestFocus() }
                                return@onPreviewKeyEvent true
                            }
                            else -> Unit
                        }
                    }
                    // 编辑态：返回与确认同样「提交并退出」，避免返回清空刚输入的内容。
                    if (isEditing && event.key == Key.Back) {
                        if (event.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                        onValueChange(editText)
                        isEditing = false
                        return@onPreviewKeyEvent true
                    }
                    // 其余键保持 KeyUp 处理
                    if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                    when {
                        isEditing && event.key.isTvConfirmKey() -> {
                            onValueChange(editText)
                            isEditing = false
                            true
                        }
                        !isEditing && event.key.isTvConfirmKey() -> {
                            editText = value
                            isEditing = true
                            true
                        }
                        else -> false
                    }
                }
                // 浏览态鼠标左键进入编辑，与确认键一致。
                .tvPointerClickable(enabled = enabled && !isEditing, onClick = {
                    editText = value
                    isEditing = true
                })
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
                    visualTransformation = if (isPassword && !passwordVisible) {
                        PasswordVisualTransformation(mask = '•')
                    } else {
                        VisualTransformation.None
                    },
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
                // 浏览态: 标签 + 值（密码默认星花）+ 编辑提示
                androidx.tv.material3.Text(
                    text = label,
                    color = TvTokens.FormTextSecondary,
                    fontSize = 15.sp,
                    modifier = Modifier.weight(1f),
                )
                androidx.tv.material3.Text(
                    text = displayValue,
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

        if (isPassword) {
            TvPasswordVisibilityEye(
                visible = passwordVisible,
                enabled = enabled,
                focusRequester = eyeFocusRequester,
                onToggle = { passwordVisible = !passwordVisible },
                onArrowLeft = {
                    runCatching { browseFocusRequester.requestFocus() }
                },
                onArrowUp = onArrowUp,
                onArrowDown = onArrowDown,
                modifier = Modifier.padding(start = 10.dp),
            )
        }
    }

    // 进入编辑：焦点落到真实输入框；确认/返回退出编辑后：焦点停在该输入行。
    androidx.compose.runtime.LaunchedEffect(isEditing) {
        if (isEditing) {
            hasEnteredEditing = true
            textFieldFocusRequester.requestFocus()
        } else if (hasEnteredEditing) {
            hasEnteredEditing = false
            runCatching { browseFocusRequester.requestFocus() }
        }
    }
}

/**
 * 密码可见性切换：默认闭眼（星花掩码），确认/点击后显示明文。
 *
 * @param visible 当前是否明文。
 * @param enabled 是否可操作。
 * @param focusRequester 焦点请求器。
 * @param onToggle 切换回调。
 * @param onArrowLeft 左键回密码输入行。
 * @param onArrowUp 上键。
 * @param onArrowDown 下键。
 * @param modifier 外层修饰器。
 */
@Composable
private fun TvPasswordVisibilityEye(
    visible: Boolean,
    enabled: Boolean,
    focusRequester: FocusRequester,
    onToggle: () -> Unit,
    onArrowLeft: (() -> Unit)?,
    onArrowUp: (() -> Unit)?,
    onArrowDown: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val borderColor = if (isFocused) TvTokens.FocusBorder else TvTokens.FormBorder
    val iconColor = if (isFocused) TvTokens.Accent else TvTokens.FormTextSecondary

    Box(
        modifier = modifier
            .size(TvTokens.FormRowHeight)
            .background(
                color = TvTokens.FormFieldBackground,
                shape = RoundedCornerShape(TvTokens.FormFieldRadius),
            )
            .border(
                width = if (isFocused) 2.dp else 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(TvTokens.FormFieldRadius),
            )
            .focusRequester(focusRequester)
            .onPreviewKeyEvent { event ->
                if (!enabled) return@onPreviewKeyEvent false
                when (event.key) {
                    Key.DirectionLeft -> {
                        if (onArrowLeft == null) return@onPreviewKeyEvent false
                        if (event.type == KeyEventType.KeyUp) return@onPreviewKeyEvent true
                        onArrowLeft.invoke()
                        return@onPreviewKeyEvent true
                    }
                    Key.DirectionUp -> {
                        if (onArrowUp == null) return@onPreviewKeyEvent false
                        if (event.type == KeyEventType.KeyUp) return@onPreviewKeyEvent true
                        onArrowUp.invoke()
                        return@onPreviewKeyEvent true
                    }
                    Key.DirectionDown -> {
                        if (onArrowDown == null) return@onPreviewKeyEvent false
                        if (event.type == KeyEventType.KeyUp) return@onPreviewKeyEvent true
                        onArrowDown.invoke()
                        return@onPreviewKeyEvent true
                    }
                    else -> Unit
                }
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                if (event.key.isTvConfirmKey()) {
                    onToggle()
                    true
                } else {
                    false
                }
            }
            .tvPointerClickable(enabled = enabled, onClick = onToggle)
            .focusable(enabled = enabled, interactionSource = interactionSource),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.size(22.dp)) {
            val w = size.width
            val h = size.height
            val stroke = Stroke(width = 1.8.dp.toPx(), cap = StrokeCap.Round)
            // 眼睛外轮廓。
            val eyePath = Path().apply {
                moveTo(w * 0.08f, h * 0.52f)
                quadraticTo(w * 0.5f, h * 0.12f, w * 0.92f, h * 0.52f)
                quadraticTo(w * 0.5f, h * 0.92f, w * 0.08f, h * 0.52f)
                close()
            }
            drawPath(path = eyePath, color = iconColor, style = stroke)
            // 瞳孔。
            drawCircle(
                color = iconColor,
                radius = w * 0.12f,
                center = Offset(w * 0.5f, h * 0.52f),
            )
            if (!visible) {
                // 斜线表示当前为隐藏（星花）状态。
                drawLine(
                    color = iconColor,
                    start = Offset(w * 0.18f, h * 0.82f),
                    end = Offset(w * 0.82f, h * 0.18f),
                    strokeWidth = 1.8.dp.toPx(),
                    cap = StrokeCap.Round,
                )
            }
        }
    }
}
