package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import kotlinx.coroutines.launch
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.relocation.BringIntoViewRequester
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
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
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TvPosterCard(
    item: TvPosterItem,
    modifier: Modifier = Modifier,
    focusRequesters: List<FocusRequester> = emptyList(),
    onFocusChanged: ((Boolean) -> Unit)? = null,
    onClick: (() -> Unit)? = null,
    /**
     * 卡片宽度；默认全局海报宽。搜索等网格可传入单元格宽，封面高度按比例缩放。
     */
    cardWidth: Dp = TvTokens.PosterWidth,
) {
    var hasCardFocus by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        // 首页多轨同时可见时，1.06 放大更稳，减少上下排互相顶动。
        targetValue = if (hasCardFocus) 1.06f else 1f,
        animationSpec = tween(durationMillis = 150),
        label = "tvPosterCardScale",
    )
    val radius = RoundedCornerShape(TvTokens.CardRadius)
    val colors = remember {
        posterBrushColors()
    }
    val coverHeight = remember(cardWidth) {
        cardWidth * (TvTokens.PosterCoverHeight.value / TvTokens.PosterWidth.value)
    }
    // 封面单独可焦时，默认 BringIntoView 只保证封面进视口；标题/副标题会被底部裁切。
    // 用整卡 requester 在获焦时把封面+文案一并滚入可见区。
    val bringIntoViewRequester = remember { BringIntoViewRequester() }
    val bringIntoViewScope = rememberCoroutineScope()

    Column(
        modifier = modifier
            .width(cardWidth)
            .bringIntoViewRequester(bringIntoViewRequester),
    ) {
        TvFocusableCard(
            modifier = Modifier
                .width(cardWidth)
                .height(coverHeight)
                .scale(scale)
                .onFocusChanged { focusState ->
                    // 卡片高亮直接跟随真实焦点，避免焦点进入后视觉仍停在顶部导航。
                    hasCardFocus = focusState.hasFocus
                    if (focusState.hasFocus) {
                        // 焦点进封面后，再把整卡（含标题副标题）请求滚入视口。
                        bringIntoViewScope.launch {
                            bringIntoViewRequester.bringIntoView()
                        }
                    }
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
                cardWidth = cardWidth,
                coverHeight = coverHeight,
            )
        }
        Column(
            // 封面与标题拉开一点，多轨纵向扫描时更易读。
            modifier = Modifier.padding(start = 4.dp, top = 10.dp, end = 4.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = item.title,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.titleMedium.copy(
                    fontWeight = if (hasCardFocus) FontWeight.SemiBold else FontWeight.Medium,
                ),
                // 获焦时标题更亮，辅助遥控器定位当前卡。
                color = if (hasCardFocus) Color.White else TvTokens.TextPrimary,
            )
            Text(
                text = item.subtitle.ifBlank { posterCaption(item.posterUrl) },
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.bodySmall.copy(fontSize = 12.sp),
                // 副标题略提亮，避免深色背景下像“缺字”。
                color = if (hasCardFocus) Color.White.copy(alpha = 0.9f) else TvTokens.TextSecondary.copy(alpha = 0.92f),
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
    cardWidth: Dp = TvTokens.PosterWidth,
    coverHeight: Dp = TvTokens.PosterCoverHeight,
) {
    val progressFraction = normalizedPosterProgress(item.progressFraction)
    Box(
        modifier = Modifier
            .width(cardWidth)
            .height(coverHeight)
            .clip(radius)
            .background(Brush.verticalGradient(colors)),
    ) {
        // 接口图失败/为空时，按片名精准匹配回退到会话内成功加载过的 URL（Coil 磁盘缓存可直接出图）。
        TvCachedTitlePosterImage(
            title = item.title,
            posterUrl = item.posterUrl,
            contentDescription = item.title,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize(),
        )
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            Color.Black.copy(alpha = 0.42f),
                        ),
                    ),
                ),
        )
        // 多集：右上角展示总集数；续播有当前集时展示「当前/总集」。
        val episodeBadgeText = when {
            item.totalEpisodes > 1 && item.episodeIndex > 0 ->
                "${item.episodeIndex}/${item.totalEpisodes}"
            item.totalEpisodes > 1 ->
                "共${item.totalEpisodes}集"
            else -> null
        }
        if (episodeBadgeText != null) {
            TvPosterEpisodeBadge(
                text = episodeBadgeText,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 8.dp, end = 8.dp),
            )
        }
        // 有评分时左上角展示，避免与右上集数徽标重叠。
        val ratingText = item.rating.trim()
        if (ratingText.isNotEmpty() && ratingText != "0" && ratingText != "0.0") {
            TvPosterEpisodeBadge(
                text = ratingText,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(top = 8.dp, start = 8.dp),
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
        targetValue = if (hasMoreCardFocus) 1.06f else 1f,
        animationSpec = tween(durationMillis = 150),
        label = "tvMorePosterCardScale",
    )

    // 与 TvPosterCard 同宽同结构：封面区 + 标题区占位，避免“查看更多”更高把下方分区顶动。
    Column(
        modifier = modifier.width(TvTokens.PosterWidth),
    ) {
        TvFocusableCard(
            modifier = Modifier
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
                    .background(
                        // 查看更多使用略亮的中性底，和海报占位区分但不抢眼。
                        color = if (hasMoreCardFocus) TvTokens.SurfaceElevated else TvTokens.PosterPlaceholder,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(
                        text = "→",
                        style = MaterialTheme.typography.displaySmall,
                        color = if (hasMoreCardFocus) TvTokens.FocusBorder else Color.White.copy(alpha = 0.92f),
                    )
                    Text(
                        text = label,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = Color.White,
                    )
                }
            }
        }
        // 标题/副标题占位与海报卡一致，LazyRow 行高不因尾卡变化。
        Column(
            // 封面与标题拉开一点，多轨纵向扫描时更易读。
            modifier = Modifier.padding(start = 6.dp, top = 12.dp, end = 6.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Text(
                text = " ",
                maxLines = 1,
                style = MaterialTheme.typography.titleMedium,
                color = Color.Transparent,
            )
            Text(
                text = " ",
                maxLines = 1,
                style = MaterialTheme.typography.bodySmall.copy(fontSize = 13.sp),
                color = Color.Transparent,
            )
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
