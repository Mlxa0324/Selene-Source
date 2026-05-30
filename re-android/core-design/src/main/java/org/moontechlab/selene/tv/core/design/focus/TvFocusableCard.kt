package org.moontechlab.selene.tv.core.design.focus

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 端可获焦卡片容器。
 *
 * @param modifier 外层修饰器。
 * @param enabled 是否允许获得焦点。
 * @param content 卡片内容。
 */
@Composable
fun TvFocusableCard(
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable () -> Unit,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val shape = RoundedCornerShape(TvTokens.CardRadius)
    val borderColor = if (isFocused) TvTokens.IvyGreen else Color.Transparent

    Box(
        modifier = modifier
            .clip(shape)
            .border(
                border = BorderStroke(TvTokens.FocusBorderWidth, borderColor),
                shape = shape,
            )
            .focusable(
                enabled = enabled,
                interactionSource = interactionSource,
            ),
    ) {
        // 内容层由业务卡片自行控制尺寸与图片加载。
        content()
    }
}
