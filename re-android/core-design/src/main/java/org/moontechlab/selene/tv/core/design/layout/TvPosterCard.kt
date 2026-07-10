package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import android.util.Log
import coil.compose.AsyncImage
import org.moontechlab.selene.tv.core.design.TvTokens
import org.moontechlab.selene.tv.core.design.focus.TvFocusableCard

/**
 * TV 海报卡片。
 *
 * @param item 影视卡片数据。
 * @param modifier 外层修饰器。
 * @param focusRequesters 需要绑定到真实卡片焦点节点的请求器。
 * @param onFocusChanged 卡片焦点变化回调。
 * @param onClick 卡片点击回调。
 */
@Composable
fun TvPosterCard(
    item: TvPosterItem,
    modifier: Modifier = Modifier,
    focusRequesters: List<FocusRequester> = emptyList(),
    onFocusChanged: ((Boolean) -> Unit)? = null,
    onClick: (() -> Unit)? = null,
) {
    var hasCardFocus by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (hasCardFocus) 1.08f else 1f,
        animationSpec = tween(durationMillis = 140),
        label = "tvPosterCardScale",
    )
    val radius = RoundedCornerShape(TvTokens.CardRadius)
    val colors = remember {
        posterBrushColors()
    }

    Column(
        modifier = modifier.width(TvTokens.PosterWidth),
    ) {
        TvFocusableCard(
            modifier = Modifier
                .width(TvTokens.PosterWidth)
                .height(TvTokens.PosterCoverHeight)
                .scale(scale)
                .onFocusChanged { focusState ->
                    // 卡片高亮直接跟随真实焦点，避免焦点进入后视觉仍停在顶部导航。
                    hasCardFocus = focusState.hasFocus
                    onFocusChanged?.invoke(focusState.hasFocus)
                },
            focusRequesters = focusRequesters,
            enabled = onClick != null,
            onPressed = onClick,
        ) {
            TvPosterCover(
                item = item,
                colors = colors,
                radius = radius,
            )
        }
        Column(
            modifier = Modifier.padding(start = 12.dp, top = 11.dp, end = 12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
        Text(
            text = item.title,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            style = MaterialTheme.typography.titleMedium,
            color = Color.White,
        )
        Text(
            text = item.subtitle.ifBlank { posterCaption(item.posterUrl) },
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            style = MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp),
            color = TvTokens.TextSecondary,
        )
    }
}
}

/**
 * TV 海报封面区域。
 *
 * @param item 海报数据。
 * @param colors 无图和加载中时使用的渐变兜底色。
 * @param radius 封面圆角。
 */
@Composable
private fun TvPosterCover(
    item: TvPosterItem,
    colors: List<Color>,
    radius: RoundedCornerShape,
) {
    val progressFraction = normalizedPosterProgress(item.progressFraction)
    Box(
        modifier = Modifier
            .width(TvTokens.PosterWidth)
            .height(TvTokens.PosterCoverHeight)
            .clip(radius)
            .background(Brush.verticalGradient(colors)),
    ) {
        if (item.posterUrl.isNotBlank()) {
            // 打印图片请求地址，方便排查封面加载问题
            Log.d("SeleneTV", "封面请求: title=${item.title}, url=${item.posterUrl}")
            // Flutter TV 使用真实封面图；Kotlin TV 也优先展示接口返回的 posterUrl。
            AsyncImage(
                model = item.posterUrl,
                contentDescription = item.title,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        }
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            Color.Black.copy(alpha = 0.34f),
                        ),
                    ),
                ),
        )
        if (item.totalEpisodes > 1 && item.episodeIndex > 0) {
            TvPosterEpisodeBadge(
                text = "${item.episodeIndex}/${item.totalEpisodes}",
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 8.dp, end = 8.dp),
            )
        }
        if (progressFraction > 0f) {
            TvPosterProgressBar(
                progressFraction = progressFraction,
                modifier = Modifier.align(Alignment.BottomStart),
            )
        }
    }
}

/**
 * TV 海报右上角集数徽标。
 *
 * @param text 徽标文案。
 * @param modifier 外层修饰器。
 */
@Composable
private fun TvPosterEpisodeBadge(
    text: String,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .background(
                color = Color.Black.copy(alpha = 0.62f),
                shape = RoundedCornerShape(6.dp),
            )
            .border(
                width = 1.dp,
                color = Color.White.copy(alpha = 0.14f),
                shape = RoundedCornerShape(6.dp),
            )
            .padding(horizontal = 8.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            color = Color.White,
        )
    }
}

/**
 * TV 海报底部播放进度条。
 *
 * @param progressFraction 已归一化的播放进度。
 * @param modifier 外层修饰器。
 */
@Composable
private fun TvPosterProgressBar(
    progressFraction: Float,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(4.dp)
            .background(Color.Black.copy(alpha = 0.38f)),
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(progressFraction)
                .height(4.dp)
                .background(TvTokens.Accent),
        )
    }
}

/**
 * TV 横向海报带尾部的查看更多卡片。
 *
 * @param modifier 外层修饰器。
 * @param label 卡片展示文案。
 * @param onClick 点击查看更多回调。
 */
@Composable
fun TvMorePosterCard(
    modifier: Modifier = Modifier,
    label: String = "查看更多",
    onClick: () -> Unit,
) {
    var hasMoreCardFocus by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (hasMoreCardFocus) 1.08f else 1f,
        animationSpec = tween(durationMillis = 140),
        label = "tvMorePosterCardScale",
    )

    Box(
        modifier = modifier
            .width(TvTokens.PosterWidth)
            .height(TvTokens.PosterHeight),
    ) {
        TvFocusableCard(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .width(TvTokens.PosterWidth)
                .height(TvTokens.PosterCoverHeight)
                .scale(scale)
                .onFocusChanged { focusState ->
                    // 更多入口沿用海报卡片的单焦点目标，确保横向列表末尾可稳定获焦。
                    hasMoreCardFocus = focusState.hasFocus
                },
            onPressed = onClick,
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.surfaceVariant),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Text(
                        text = "→",
                        style = MaterialTheme.typography.displaySmall,
                        color = if (hasMoreCardFocus) TvTokens.FocusBorder else Color.White,
                    )
                    Text(
                        text = label,
                        style = MaterialTheme.typography.titleMedium,
                        color = Color.White,
                    )
                }
            }
        }
    }
}

/**
 * 计算海报卡片底图颜色。
 *
 * @return 用于海报背景的固定浅灰渐变色。
 */
private fun posterBrushColors(): List<Color> {
    // 海报首屏统一使用固定浅灰，避免无图时出现五颜六色的视觉噪音。
    return listOf(
        TvTokens.PosterPlaceholder,
        TvTokens.PosterPlaceholder,
        TvTokens.PosterPlaceholder,
    )
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
