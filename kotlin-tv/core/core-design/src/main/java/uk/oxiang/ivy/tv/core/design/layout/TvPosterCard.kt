package uk.oxiang.ivy.tv.core.design.layout

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.LinearEasing
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import coil.compose.SubcomposeAsyncImage
import coil.compose.SubcomposeAsyncImageContent
import kotlinx.coroutines.delay
import uk.oxiang.ivy.tv.core.design.LocalTvThemePalette
import uk.oxiang.ivy.tv.core.design.TvTokens
import uk.oxiang.ivy.tv.core.design.focus.TvFocusableCard
import uk.oxiang.ivy.tv.core.design.theme.TvThemeColors

/**
 * TV 海报卡片焦点边框颜色，对齐 Flutter `TvVideoCard` 获焦封面描边 `#E2E6EA`。
 */
private val PosterFocusBorderColor = Color(0xFFE2E6EA)

/**
 * TV 海报卡片未获焦封面描边颜色，对齐 Flutter `TvThemeColors.cardSurfaceBorder`。
 */
private val PosterIdleBorderColor = TvThemeColors.cardSurfaceBorder

/**
 * TV 海报卡片。
 *
 * 完整对齐 Flutter `TvVideoCard`（`lib/tv_app/widgets/tv_video_card.dart`）视觉规格：
 * 尺寸 158x300（封面 237）、获焦缩放 1.08（140ms easeOutCubic）、获焦封面描边
 * `#E2E6EA` 3px + 外阴影、获焦停留 300ms 后触发一次 1800ms 横向扫光、加载骨架
 * 复用同款横向扫光（最多 2 轮）、右上角多集徽标、底部播放进度条。
 *
 * @param item 影视卡片数据。
 * @param modifier 外层修饰器。
 * @param focusRequesters 需要绑定到真实卡片焦点节点的请求器。
 * @param onFocusChanged 卡片焦点变化回调。
 * @param onClick 卡片点击回调。
 * @param focusMemoryGroupKey 焦点记忆分组标识，透传给 [TvFocusableCard]。
 * @param directionalRepeatThrottleGroupKey 方向键长按节流分组标识，透传给 [TvFocusableCard]。
 */
@Composable
fun TvPosterCard(
    item: TvPosterItem,
    modifier: Modifier = Modifier,
    focusRequesters: List<FocusRequester> = emptyList(),
    onFocusChanged: ((Boolean) -> Unit)? = null,
    onClick: (() -> Unit)? = null,
    focusMemoryGroupKey: Any? = null,
    directionalRepeatThrottleGroupKey: Any? = null,
) {
    var hasCardFocus by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (hasCardFocus) TvTokens.PosterFocusedScale else 1f,
        animationSpec = tween(
            durationMillis = TvTokens.PosterFocusScaleDurationMs,
            easing = PosterFocusScaleEasing,
        ),
        label = "tvPosterCardScale",
    )

    Column(
        modifier = modifier
            .width(TvTokens.PosterWidth)
            .scale(scale),
    ) {
        TvFocusableCard(
            modifier = Modifier
                .width(TvTokens.PosterWidth)
                .height(TvTokens.PosterCoverHeight)
                .onFocusChanged { focusState ->
                    // 卡片高亮直接跟随真实焦点，避免焦点进入后视觉仍停在顶部导航。
                    hasCardFocus = focusState.hasFocus
                    onFocusChanged?.invoke(focusState.hasFocus)
                },
            focusRequesters = focusRequesters,
            enabled = onClick != null,
            onPressed = onClick,
            focusMemoryGroupKey = focusMemoryGroupKey,
            directionalRepeatThrottleGroupKey = directionalRepeatThrottleGroupKey,
            // 封面自行绘制浅色描边+阴影，关闭内置白色描边避免重复视觉。
            showFocusBorder = false,
        ) {
            TvPosterCover(item = item, hasFocus = hasCardFocus)
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
                text = item.subtitle,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.bodySmall,
                color = TvTokens.TextSecondary,
            )
        }
    }
}

/**
 * TV 海报卡片获焦缩放曲线，对齐 Flutter `Curves.easeOutCubic`。
 */
private val PosterFocusScaleEasing = CubicBezierEasing(0.215f, 0.61f, 0.355f, 1f)

/**
 * TV 海报封面区域。
 *
 * @param item 海报数据。
 * @param hasFocus 卡片是否处于真实焦点。
 */
@Composable
private fun TvPosterCover(
    item: TvPosterItem,
    hasFocus: Boolean,
) {
    val radius = RoundedCornerShape(TvTokens.CardRadius)
    val progressFraction = normalizedPosterProgress(item.progressFraction)
    val borderColor = if (hasFocus) PosterFocusBorderColor else PosterIdleBorderColor
    val borderWidth = if (hasFocus) TvTokens.FocusBorderWidth else 1.dp

    Box(
        modifier = Modifier
            .width(TvTokens.PosterWidth)
            .height(TvTokens.PosterCoverHeight)
            .then(
                if (hasFocus) {
                    // 获焦外阴影：blur 22, offset (0,10), alpha 0.08，对齐 Flutter BoxShadow。
                    Modifier.shadow(
                        elevation = 11.dp,
                        shape = radius,
                        ambientColor = PosterFocusBorderColor.copy(alpha = 0.08f),
                        spotColor = PosterFocusBorderColor.copy(alpha = 0.08f),
                    )
                } else {
                    Modifier
                },
            )
            .clip(radius)
            .background(TvThemeColors.cardSurface)
            .border(width = borderWidth, color = borderColor, shape = radius),
    ) {
        if (item.posterUrl.isNotBlank()) {
            SubcomposeAsyncImage(
                model = item.posterUrl,
                contentDescription = item.title,
                modifier = Modifier.fillMaxSize(),
            ) {
                val state = painter.state
                when (state) {
                    is coil.compose.AsyncImagePainter.State.Loading -> TvCoverLoadingSkeleton()
                    is coil.compose.AsyncImagePainter.State.Error -> TvCoverFallback()
                    else -> SubcomposeAsyncImageContent(contentScale = ContentScale.Crop)
                }
            }
        } else {
            TvCoverFallback()
        }
        // 焦点/未焦点统一底部渐暗遮罩，获焦时略浅，让封面在放大后仍保持层次。
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            Color.Black.copy(alpha = if (hasFocus) 0.20f else 0.34f),
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
        TvPosterFocusSweepOverlay(active = hasFocus)
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
    val accent = LocalTvThemePalette.current.accent
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
                .background(accent),
        )
    }
}

/**
 * TV 海报封面占位。
 *
 * 无封面地址或图片加载失败时展示，使用深色渐变+播放图标提示。
 */
@Composable
internal fun TvCoverFallback(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(Color(0xFF252B2E), TvTokens.Surface),
                ),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .width(58.dp)
                .height(58.dp)
                .clip(RoundedCornerShape(50))
                .border(width = 2.dp, color = Color(0xFF5E6B72), shape = RoundedCornerShape(50)),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = "▶", color = Color(0xFF7A878E), style = MaterialTheme.typography.titleLarge)
        }
    }
}

/**
 * TV 海报封面加载骨架。
 *
 * 用从左上到右下的柔和横向雨刷光带提示图片正在首次加载，最多播放 [maxSweepCount] 轮，
 * 对齐 Flutter `TvCoverLoadingSkeleton`。
 */
@Composable
internal fun TvCoverLoadingSkeleton(modifier: Modifier = Modifier) {
    var completedSweepCount by remember { mutableIntStateOf(0) }
    val progress = remember { Animatable(0f) }

    LaunchedEffect(Unit) {
        while (completedSweepCount < maxSweepCount) {
            progress.snapTo(0f)
            progress.animateTo(1f, animationSpec = tween(SweepDurationMs, easing = LinearEasing))
            completedSweepCount += 1
        }
    }

    Box(
        modifier = modifier.fillMaxSize(),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(Color(0xFF20282B), Color(0xFF14191B)),
                    ),
                ),
        )
        val translate = (progress.value * 2.6f) - 1.3f
        Box(
            modifier = Modifier
                .fillMaxSize()
                .horizontalSweepOffset(translate)
                .background(
                    Brush.linearGradient(
                        colorStops = arrayOf(
                            0f to Color.Transparent,
                            0.10f to Color(0x12E4EAED),
                            0.26f to Color(0x1EE4EAED),
                            0.40f to Color(0x2AE4EAED),
                            0.60f to Color(0x2AE4EAED),
                            0.74f to Color(0x1EE4EAED),
                            0.90f to Color(0x12E4EAED),
                            1f to Color.Transparent,
                        ),
                        start = Offset(-1.2f, 0f),
                        end = Offset(1.2f, 0f),
                    ),
                ),
        )
    }
}

/**
 * TV 海报卡片获焦后的一次性雨刷动画。
 *
 * 获焦停留 [FocusSweepDelayMs] 后触发一次 [SweepDurationMs] 横向扫光，纯横向不带
 * 纵向偏移，对齐 Flutter `_TvFocusSweepOverlay`。
 */
@Composable
private fun TvPosterFocusSweepOverlay(active: Boolean) {
    var showSweep by remember { mutableStateOf(false) }
    val progress = remember { Animatable(0f) }

    LaunchedEffect(active) {
        if (active) {
            delay(FocusSweepDelayMs.toLong())
            showSweep = true
            progress.snapTo(0f)
            progress.animateTo(1f, animationSpec = tween(SweepDurationMs, easing = LinearEasing))
            showSweep = false
        } else {
            showSweep = false
            progress.snapTo(0f)
        }
    }

    if (!showSweep) {
        return
    }
    val translate = (progress.value * 2.8f) - 1.4f
    Box(
        modifier = Modifier
            .fillMaxSize()
            .horizontalSweepOffset(translate)
            .alpha(1f - progress.value)
            .background(
                Brush.linearGradient(
                    colorStops = arrayOf(
                        0f to Color.Transparent,
                        0.08f to Color(0x12FFFFFF),
                        0.24f to Color(0x20FFFFFF),
                        0.38f to Color(0x2CFFFFFF),
                        0.62f to Color(0x2CFFFFFF),
                        0.76f to Color(0x20FFFFFF),
                        0.92f to Color(0x12FFFFFF),
                        1f to Color.Transparent,
                    ),
                    start = Offset(-1.2f, 0f),
                    end = Offset(1.2f, 0f),
                ),
            ),
    )
}

/**
 * 骨架雨刷最大播放轮次，对齐 Flutter `TvCoverLoadingSkeleton.maxSweepCount`。
 */
private const val maxSweepCount = 2

/**
 * 焦点雨刷/骨架雨刷动画时长，对齐 Flutter `TvVideoCard.shimmerDuration`。
 */
private const val SweepDurationMs = 1800

/**
 * 焦点雨刷触发延迟，对齐 Flutter `TvVideoCard.focusSweepDelay`。
 */
private const val FocusSweepDelayMs = 300

/**
 * 按封面固定宽度 [TvTokens.PosterWidth] 水平位移，用于横向扫光动画。
 *
 * 封面宽度是编译期已知常量，直接用 Dp 运算即可，不需要额外测量实际像素宽度。
 *
 * @param fraction 位移比例，以封面宽度为单位。
 */
private fun Modifier.horizontalSweepOffset(fraction: Float): Modifier {
    return this.offset(x = TvTokens.PosterWidth * fraction)
}

/**
 * TV 横向海报带尾部的查看更多卡片。
 *
 * 宽度等于 [TvTokens.PosterWidth]，高度等于 [TvTokens.PosterCoverHeight]，对齐
 * `tv-mode.md` 首页横向分区超出 15 条时的「查看更多」入口规格。
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
        targetValue = if (hasMoreCardFocus) TvTokens.PosterFocusedScale else 1f,
        animationSpec = tween(
            durationMillis = TvTokens.PosterFocusScaleDurationMs,
            easing = PosterFocusScaleEasing,
        ),
        label = "tvMorePosterCardScale",
    )

    TvFocusableCard(
        modifier = modifier
            .width(TvTokens.PosterWidth)
            .height(TvTokens.PosterCoverHeight)
            .scale(scale)
            .onFocusChanged { focusState -> hasMoreCardFocus = focusState.hasFocus },
        onPressed = onClick,
        showFocusBorder = false,
    ) {
        val borderColor = if (hasMoreCardFocus) PosterFocusBorderColor else PosterIdleBorderColor
        val borderWidth = if (hasMoreCardFocus) TvTokens.FocusBorderWidth else 1.dp
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(TvTokens.CardRadius))
                .background(TvTokens.SurfaceElevated)
                .border(
                    width = borderWidth,
                    color = borderColor,
                    shape = RoundedCornerShape(TvTokens.CardRadius),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(
                    text = "→",
                    style = MaterialTheme.typography.displaySmall,
                    color = if (hasMoreCardFocus) PosterFocusBorderColor else Color.White,
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
