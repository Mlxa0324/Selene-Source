package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.border
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 海报卡片。
 *
 * @param item 影视卡片数据。
 * @param modifier 外层修饰器。
 * @param onClick 卡片点击回调。
 */
@Composable
fun TvPosterCard(
    item: TvPosterItem,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isFocused by interactionSource.collectIsFocusedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isFocused) 1.08f else 1f,
        animationSpec = tween(durationMillis = 140),
        label = "tvPosterCardScale",
    )
    val radius = RoundedCornerShape(TvTokens.CardRadius)
    val colors = remember(item.id, item.posterUrl) {
        posterBrushColors(item.id, item.posterUrl)
    }

    androidx.compose.foundation.layout.Box(
        modifier = modifier
            .width(TvTokens.PosterWidth)
            .height(TvTokens.PosterHeight)
            .scale(scale)
            .clip(radius)
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .clickable(
                enabled = onClick != null,
                interactionSource = interactionSource,
                indication = null,
                onClick = { onClick?.invoke() },
            )
            .border(
                width = if (isFocused) TvTokens.FocusBorderWidth else 1.dp,
                color = if (isFocused) TvTokens.FocusBorder else Color.Transparent,
                shape = radius,
            ),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.verticalGradient(colors)),
        ) {
            Column(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = item.title,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.titleMedium,
                    color = Color.White,
                )
                Text(
                    text = item.subtitle.ifBlank { posterCaption(item.posterUrl) },
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.78f),
                )
            }
        }
    }
}

/**
 * 计算海报卡片底图颜色。
 *
 * @param seed1 第一层哈希种子。
 * @param seed2 第二层哈希种子。
 * @return 用于海报背景的渐变色。
 */
private fun posterBrushColors(seed1: String, seed2: String): List<Color> {
    val hash = (seed1 + seed2).hashCode()
    val palette = listOf(
        Color(0xFF16C784),
        Color(0xFF1E90FF),
        Color(0xFF8B5CF6),
        Color(0xFFFFB020),
        Color(0xFFE25555),
        Color(0xFF2DD4BF),
    )
    val base = palette[(hash and Int.MAX_VALUE) % palette.size]
    val deep = base.copy(alpha = 0.24f)
    val mid = base.copy(alpha = 0.44f)
    val light = base.copy(alpha = 0.82f)
    return listOf(deep, mid, light)
}

/**
 * 生成海报卡片辅助文案。
 *
 * @param posterUrl 海报地址。
 * @return 海报卡片底部辅助文案。
 */
private fun posterCaption(posterUrl: String): String {
    if (posterUrl.isBlank()) {
        return "默认海报"
    }
    val host = runCatching {
        java.net.URI(posterUrl).host
    }.getOrNull()
    return host?.takeIf { it.isNotBlank() } ?: posterUrl
}
