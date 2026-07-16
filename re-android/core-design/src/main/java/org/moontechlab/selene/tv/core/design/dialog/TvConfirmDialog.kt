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
import androidx.compose.ui.draw.clip
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
import kotlinx.coroutines.delay
import org.moontechlab.selene.tv.core.design.TvTokens

/** 弹窗卡片圆角。 */
private val DialogCorner = 16.dp

/** 底部动作按钮圆角。 */
private val ActionCorner = 12.dp

/** 弹窗卡片底色（略高于页面底，避免脏灰块）。 */
private val DialogSurface = Color(0xFF252830)

/** 未获焦取消按钮底色。 */
private val CancelIdleFill = Color(0xFF343944)

/** 未获焦确认按钮底色。 */
private val ConfirmIdleFill = Color(0xFF2F333C)

/** 副文案色。 */
private val MessageColor = Color(0xFFB6BCC8)

/**
 * TV 公共确认弹窗。
 *
 * 用于「删除全部 / 退出应用」等需二次确认的场景：
 * - 底部左「取消」、右「确认」，按钮各自圆角
 * - 卡片四角圆角 + clip，避免底栏把圆角盖成直角
 * - **默认焦点在取消**，降低误触确认风险
 * - 返回键 / Esc 视为取消
 *
 * @param title 弹窗标题。
 * @param message 弹窗说明。
 * @param confirmLabel 右侧确认按钮文案，默认「确认」。
 * @param cancelLabel 左侧取消按钮文案，默认「取消」。
 * @param onConfirm 确认回调。
 * @param onDismiss 取消、返回或点遮罩关闭回调。
 * @param confirmIsDanger 确认是否用危险色强调（删除/清空类）。
 */
@Composable
fun TvConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String = "确认",
    cancelLabel: String = "取消",
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    confirmIsDanger: Boolean = false,
) {
    val cancelFocusRequester = remember { FocusRequester() }
    val confirmFocusRequester = remember { FocusRequester() }
    // 默认焦点落在取消；Dialog 挂载后可能晚一帧才可焦，短重试保证落点。
    LaunchedEffect(Unit) {
        for (attempt in 0 until 16) {
            delay(16)
            val ok = runCatching { cancelFocusRequester.requestFocus() }.getOrDefault(false)
            if (ok) {
                return@LaunchedEffect
            }
        }
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
                // 整体收窄，避免电视大屏上占半屏。
                .widthIn(min = 280.dp, max = 312.dp)
                .width(312.dp)
                .clip(RoundedCornerShape(DialogCorner))
                .background(
                    color = DialogSurface,
                    shape = RoundedCornerShape(DialogCorner),
                )
                .border(
                    width = 1.dp,
                    color = Color.White.copy(alpha = 0.08f),
                    shape = RoundedCornerShape(DialogCorner),
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
                }
                .padding(horizontal = 20.dp, vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = title,
                style = androidx.tv.material3.MaterialTheme.typography.titleMedium.copy(
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 17.sp,
                    lineHeight = 24.sp,
                ),
                color = Color.White,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = message,
                style = androidx.tv.material3.MaterialTheme.typography.bodyMedium.copy(
                    fontWeight = FontWeight.Normal,
                    fontSize = 13.sp,
                    lineHeight = 18.sp,
                ),
                color = MessageColor,
                textAlign = TextAlign.Center,
            )
            Spacer(modifier = Modifier.height(18.dp))

            // 双按钮各自圆角，左右留缝，不再用直角通栏分割。
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TvConfirmDialogAction(
                    label = cancelLabel,
                    focusRequester = cancelFocusRequester,
                    testTag = "tv-confirm-cancel-button",
                    onClick = onDismiss,
                    idleFill = CancelIdleFill,
                    onArrowRight = { confirmFocusRequester.requestFocus() },
                    modifier = Modifier.weight(1f),
                )
                TvConfirmDialogAction(
                    label = confirmLabel,
                    focusRequester = confirmFocusRequester,
                    testTag = "tv-confirm-confirm-button",
                    onClick = onConfirm,
                    idleFill = ConfirmIdleFill,
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
 * 确认弹窗底部动作按钮（独立圆角胶囊块）。
 */
@Composable
private fun TvConfirmDialogAction(
    label: String,
    focusRequester: FocusRequester,
    testTag: String,
    onClick: () -> Unit,
    idleFill: Color,
    modifier: Modifier = Modifier,
    accentWhenFocused: Boolean = false,
    danger: Boolean = false,
    onArrowLeft: (() -> Unit)? = null,
    onArrowRight: (() -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(ActionCorner)
    val background = when {
        isFocused && danger -> TvTokens.Danger
        isFocused && accentWhenFocused -> TvTokens.Accent
        isFocused -> TvTokens.Accent
        else -> idleFill
    }
    val borderColor = when {
        isFocused -> Color.White.copy(alpha = 0.88f)
        else -> Color.White.copy(alpha = 0.06f)
    }
    Box(
        modifier = modifier
            .testTag(testTag)
            .height(44.dp)
            .clip(shape)
            .background(color = background, shape = shape)
            .border(width = if (isFocused) 2.dp else 1.dp, color = borderColor, shape = shape)
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
            fontWeight = FontWeight.SemiBold,
        )
    }
}
