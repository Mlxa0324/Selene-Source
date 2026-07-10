package uk.oxiang.ivy.tv.core.design.dialog

import androidx.compose.animation.core.tween
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.tv.material3.Text
import uk.oxiang.ivy.tv.core.design.LocalTvThemePalette

/**
 * TV 风格确认弹窗。
 *
 * 精确对齐 Flutter `TvConfirmDialog`（`lib/tv_app/widgets/tv_confirm_dialog.dart`）的视觉与交互：
 * 372dp 弹窗宽度、124dp 内容区、58dp 底部双按钮操作区，深灰卡片 + 分隔线，
 * 获焦按钮背景切换为当前 TV 主题色。
 *
 * @param title 弹窗标题。
 * @param message 弹窗说明。
 * @param confirmLabel 确认按钮文案。
 * @param cancelLabel 取消按钮文案。
 * @param onConfirm 确认回调。
 * @param onDismiss 取消或关闭回调（含返回键）。
 */
@Composable
fun TvConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String,
    cancelLabel: String = "取消",
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    val cancelFocusRequester = remember { FocusRequester() }
    val confirmFocusRequester = remember { FocusRequester() }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(dismissOnBackPress = true, dismissOnClickOutside = false),
    ) {
        Column(
            modifier = Modifier
                .width(TvConfirmDialogWidth)
                .clip(RoundedCornerShape(17.dp))
                .background(TvConfirmDialogSurface),
        ) {
            Box(
                modifier = Modifier
                    .height(TvConfirmDialogContentHeight)
                    .padding(start = 28.dp, top = 22.dp, end = 28.dp, bottom = 18.dp),
                contentAlignment = Alignment.Center,
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = title,
                        textAlign = TextAlign.Center,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                    )
                    androidx.compose.foundation.layout.Spacer(modifier = Modifier.height(14.dp))
                    Text(
                        text = message,
                        textAlign = TextAlign.Center,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = TvConfirmDialogMessageColor,
                    )
                }
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(TvConfirmDialogActionHeight)
                    .background(TvConfirmDialogActionBackground)
                    .padding(top = 1.dp),
            ) {
                TvConfirmDialogActionButton(
                    label = cancelLabel,
                    focusRequester = cancelFocusRequester,
                    autoFocus = true,
                    onClick = onDismiss,
                    onArrowRight = { confirmFocusRequester.requestFocus() },
                    modifier = Modifier.weight(1f),
                )
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .fillMaxHeight()
                        .background(TvConfirmDialogDividerColor),
                )
                TvConfirmDialogActionButton(
                    label = confirmLabel,
                    focusRequester = confirmFocusRequester,
                    autoFocus = false,
                    onClick = onConfirm,
                    onArrowLeft = { cancelFocusRequester.requestFocus() },
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

private val TvConfirmDialogWidth = 372.dp
private val TvConfirmDialogContentHeight = 124.dp
private val TvConfirmDialogActionHeight = 58.dp
private val TvConfirmDialogSurface = Color(0xFF3B3B3D)
private val TvConfirmDialogActionBackground = Color(0xFF535355)
private val TvConfirmDialogDividerColor = Color(0xFF666669)
private val TvConfirmDialogMessageColor = Color(0xFFD6D8DD)

/**
 * 确认弹窗底部单个操作按钮。
 *
 * 获焦背景切换为当前 TV 主题色，与 Flutter `_TvConfirmDialogActionButton` 一致。
 */
@Composable
private fun TvConfirmDialogActionButton(
    label: String,
    focusRequester: FocusRequester,
    autoFocus: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onArrowLeft: (() -> Unit)? = null,
    onArrowRight: (() -> Unit)? = null,
) {
    val palette = LocalTvThemePalette.current
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val backgroundColor by animateColorAsState(
        targetValue = if (isFocused) palette.accent else Color.Transparent,
        animationSpec = tween(140),
    )
    val textColor = if (isFocused) palette.selectedText else Color.White

    Box(
        modifier = modifier
            .height(TvConfirmDialogActionHeight)
            .background(backgroundColor)
            .focusRequester(focusRequester)
            .onPreviewKeyEvent { event ->
                if (event.type != KeyEventType.KeyUp) return@onPreviewKeyEvent false
                when (event.key) {
                    Key.Enter, Key.DirectionCenter -> {
                        onClick()
                        true
                    }
                    Key.DirectionLeft -> {
                        if (onArrowLeft != null) {
                            onArrowLeft()
                            true
                        } else {
                            false
                        }
                    }
                    Key.DirectionRight -> {
                        if (onArrowRight != null) {
                            onArrowRight()
                            true
                        } else {
                            false
                        }
                    }
                    else -> false
                }
            }
            .focusable(interactionSource = interactionSource),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            color = textColor,
        )
    }

    if (autoFocus) {
        LaunchedEffect(Unit) {
            focusRequester.requestFocus()
        }
    }
}
