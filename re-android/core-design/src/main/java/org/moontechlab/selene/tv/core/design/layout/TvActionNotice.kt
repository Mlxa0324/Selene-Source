package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 底部轻提示浮层（公共组件）。
 *
 * 深色胶囊条、不占满宽、不抢主题色；从底部轻滑入，默认约 2.4 秒后消失。
 *
 * @param text 提示文案。
 * @param visible 是否可见。
 * @param modifier 外层修饰器（通常用于 BottomCenter 对齐与外边距）。
 * @param onDismiss 消失回调。
 * @param durationMs 展示时长（毫秒）。
 */
@Composable
fun TvActionNotice(
    text: String,
    visible: Boolean,
    modifier: Modifier = Modifier,
    onDismiss: () -> Unit = {},
    durationMs: Long = 2400L,
) {
    val shape = RoundedCornerShape(22.dp)
    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center,
    ) {
        AnimatedVisibility(
            visible = visible && text.isNotBlank(),
            enter = slideInVertically(initialOffsetY = { it / 2 }) + fadeIn(),
            exit = slideOutVertically(targetOffsetY = { it / 2 }) + fadeOut(),
        ) {
            Box(
                modifier = Modifier
                    .widthIn(min = 120.dp, max = 360.dp)
                    .wrapContentWidth()
                    .clip(shape)
                    .background(TvTokens.SurfaceElevated.copy(alpha = 0.94f))
                    .border(
                        width = 1.dp,
                        color = TvTokens.TextSecondary.copy(alpha = 0.22f),
                        shape = shape,
                    )
                    .padding(horizontal = 22.dp, vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                androidx.tv.material3.Text(
                    text = text,
                    color = TvTokens.TextPrimary,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                    maxLines = 3,
                    lineHeight = 20.sp,
                )
            }
        }
    }

    // 每次 visible/text 变化重新计时，避免同文案二次弹出不自动收起。
    LaunchedEffect(visible, text) {
        if (!visible || text.isBlank()) {
            return@LaunchedEffect
        }
        delay(durationMs)
        onDismiss()
    }
}
