package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 底部动画提示浮层。
 *
 * 从底部滑入，自动 2 秒后消失。
 *
 * @param text 提示文案。
 * @param visible 是否可见。
 * @param modifier 外层修饰器。
 * @param onDismiss 消失回调。
 * @param durationMs 展示时长（毫秒）。
 */
@Composable
fun TvActionNotice(
    text: String,
    visible: Boolean,
    modifier: Modifier = Modifier,
    onDismiss: () -> Unit = {},
    durationMs: Long = 2000L,
) {
    AnimatedVisibility(
        visible = visible,
        enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
        exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
        modifier = modifier,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 64.dp, vertical = 24.dp)
                .background(
                    color = TvTokens.Accent.copy(alpha = 0.9f),
                    shape = RoundedCornerShape(TvTokens.CardRadius),
                )
                .padding(horizontal = 32.dp, vertical = 16.dp),
            contentAlignment = Alignment.Center,
        ) {
            androidx.tv.material3.Text(
                text = text,
                color = androidx.compose.ui.graphics.Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }

    if (visible) {
        LaunchedEffect(text) {
            delay(durationMs)
            onDismiss()
        }
    }
}
