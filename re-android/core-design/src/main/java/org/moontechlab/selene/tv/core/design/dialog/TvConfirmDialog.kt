package org.moontechlab.selene.tv.core.design.dialog

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.tv.material3.Text
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 公共确认弹窗（对齐 Flutter [TvConfirmDialog]）。
 *
 * 用于删除全部、退出等需二次确认的场景；返回键 / Esc 视为取消。
 *
 * @param title 弹窗标题。
 * @param message 弹窗说明。
 * @param confirmLabel 右侧确认按钮文案。
 * @param cancelLabel 左侧取消按钮文案。
 * @param onConfirm 确认回调。
 * @param onDismiss 取消、返回或点遮罩关闭回调。
 * @param confirmIsDanger 确认是否用危险色强调（删除/清空类）。
 */
@Composable
fun TvConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String,
    cancelLabel: String = "取消",
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    confirmIsDanger: Boolean = false,
) {
    val cancelFocusRequester = remember { FocusRequester() }
    val confirmFocusRequester = remember { FocusRequester() }
    // 默认焦点落在取消，避免误触确认。
    LaunchedEffect(Unit) {
        runCatching { cancelFocusRequester.requestFocus() }
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(
            dismissOnBackPress = true,
            dismissOnClickOutside = false,
            usePlatformDefaultWidth = false,
        ),
    ) {
        Column(
            modifier = Modifier
                .testTag("tv-confirm-dialog")
                .widthIn(min = 320.dp, max = 372.dp)
                .width(372.dp)
                .background(
                    color = Color(0xFF3B3B3D),
                    shape = RoundedCornerShape(17.dp),
                )
                .onPreviewKeyEvent { event ->
                    // Esc / 返回：统一当取消，关闭弹窗。
                    if (
                        event.type == KeyEventType.KeyDown &&
                        (event.key == Key.Back || event.key == Key.Escape)
                    ) {
                        onDismiss()
                        return@onPreviewKeyEvent true
                    }
                    false
                },
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 28.dp, vertical = 22.dp)
                    .height(124.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = title,
                    style = androidx.tv.material3.MaterialTheme.typography.titleLarge.copy(
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp,
                    ),
                    color = Color.White,
                    textAlign = TextAlign.Center,
                )
                Spacer(modifier = Modifier.height(14.dp))
                Text(
                    text = message,
                    style = androidx.tv.material3.MaterialTheme.typography.bodyMedium.copy(
                        fontWeight = FontWeight.Medium,
                        fontSize = 14.sp,
                    ),
                    color = Color(0xFFD6D8DD),
                    textAlign = TextAlign.Center,
                )
            }

            // 底部分割 + 双按钮（对齐 Flutter：左取消、右确认）。
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(Color(0xFF666669)),
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(58.dp)
                    .background(Color(0xFF535355)),
            ) {
                TvConfirmDialogAction(
                    label = cancelLabel,
                    focusRequester = cancelFocusRequester,
                    testTag = "tv-confirm-cancel-button",
                    onClick = onDismiss,
                    onArrowRight = { confirmFocusRequester.requestFocus() },
                    modifier = Modifier.weight(1f),
                )
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .height(58.dp)
                        .background(Color(0xFF666669)),
                )
                TvConfirmDialogAction(
                    label = confirmLabel,
                    focusRequester = confirmFocusRequester,
                    testTag = "tv-confirm-confirm-button",
                    onClick = onConfirm,
                    accentWhenFocused = true,
                    danger = confirmIsDanger,
                    onArrowLeft = { cancelFocusRequester.requestFocus() },
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

/**
 * 确认弹窗底部动作按钮。
 */
@Composable
private fun TvConfirmDialogAction(
    label: String,
    focusRequester: FocusRequester,
    testTag: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    accentWhenFocused: Boolean = false,
    danger: Boolean = false,
    onArrowLeft: (() -> Unit)? = null,
    onArrowRight: (() -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val background = when {
        isFocused && (accentWhenFocused || danger) -> {
            if (danger) TvTokens.Danger else TvTokens.Accent
        }
        isFocused -> TvTokens.Accent
        else -> Color.Transparent
    }
    Box(
        modifier = modifier
            .testTag(testTag)
            .fillMaxWidth()
            .height(58.dp)
            .background(background)
            .focusRequester(focusRequester)
            .focusable(interactionSource = interactionSource)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick,
            )
            .onPreviewKeyEvent { event ->
                if (
                    event.key == Key.Enter ||
                    event.key == Key.DirectionCenter ||
                    event.key == Key.NumPadEnter ||
                    event.key == Key.Spacebar
                ) {
                    if (event.type == KeyEventType.KeyUp) {
                        onClick()
                    }
                    return@onPreviewKeyEvent true
                }
                if (event.type == KeyEventType.KeyDown) {
                    when (event.key) {
                        Key.DirectionLeft -> {
                            onArrowLeft?.invoke()
                            return@onPreviewKeyEvent onArrowLeft != null
                        }
                        Key.DirectionRight -> {
                            onArrowRight?.invoke()
                            return@onPreviewKeyEvent onArrowRight != null
                        }
                        else -> Unit
                    }
                }
                false
            },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}
