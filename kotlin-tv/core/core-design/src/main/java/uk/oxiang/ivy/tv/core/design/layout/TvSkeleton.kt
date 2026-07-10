package uk.oxiang.ivy.tv.core.design.layout

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import uk.oxiang.ivy.tv.core.design.TvTokens

/**
 * 骨架屏公共微光动画。
 *
 * @return 0.25..0.55 脉动 alpha 值。
 */
@Composable
fun rememberShimmerAlpha(): Float {
    val infiniteTransition = rememberInfiniteTransition()
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.25f,
        targetValue = 0.55f,
        animationSpec = infiniteRepeatable(
            animation = tween(900, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse,
        ),
    )
    return alpha
}

/**
 * 骨架屏占位文本行。
 *
 * @param widthFraction 宽度占满宽比例。
 * @param modifier 外层修饰器。
 */
@Composable
fun TvSkeletonTextLine(
    widthFraction: Float = 0.7f,
    modifier: Modifier = Modifier,
) {
    val shimmer = rememberShimmerAlpha()
    Box(
        modifier = modifier
            .fillMaxWidth(widthFraction)
            .height(14.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(Color.White.copy(alpha = shimmer * 0.12f)),
    )
}

/**
 * 骨架屏海报卡片占位。
 *
 * @param width 卡片宽度。
 * @param coverHeight 封面高度。
 * @param modifier 外层修饰器。
 */
@Composable
fun TvSkeletonPoster(
    width: Dp = TvTokens.PosterWidth,
    coverHeight: Dp = TvTokens.PosterCoverHeight,
    modifier: Modifier = Modifier,
) {
    val shimmer = rememberShimmerAlpha()
    val shape = RoundedCornerShape(TvTokens.CardRadius)
    Column(
        modifier = modifier.width(width),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // 封面占位
        Box(
            modifier = Modifier
                .width(width)
                .height(coverHeight)
                .clip(shape)
                .background(Color.White.copy(alpha = shimmer * 0.12f)),
        )
        // 标题行占位
        Box(
            modifier = Modifier
                .fillMaxWidth(0.85f)
                .height(12.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Color.White.copy(alpha = shimmer * 0.1f)),
        )
        // 副标题行占位
        Box(
            modifier = Modifier
                .fillMaxWidth(0.6f)
                .height(10.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Color.White.copy(alpha = shimmer * 0.08f)),
        )
    }
}

/**
 * 骨架屏分区标题 + 海报横滑行。
 *
 * @param modifier 外层修饰器。
 */
@Composable
fun TvSkeletonSection(
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // 分区标题占位
        TvSkeletonTextLine(widthFraction = 0.22f)
        Spacer(modifier = Modifier.height(4.dp))
        // 海报横滑行
        LazyRow(horizontalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing)) {
            items(10) {
                TvSkeletonPoster()
            }
        }
    }
}

/**
 * 首页骨架屏 —— 多个分区 + 横滑行。
 *
 * @param modifier 外层修饰器。
 * @param contentFocusRequester 顶部导航下探时使用的内容焦点请求器。
 */
@Composable
fun TvHomeSkeleton(
    modifier: Modifier = Modifier,
    contentFocusRequester: FocusRequester? = null,
) {
    Column(
        modifier = modifier
            .loadingFocusTarget(contentFocusRequester)
            .padding(
                start = TvTokens.PageHorizontalPadding,
                end = TvTokens.PageHorizontalPadding,
            ),
        verticalArrangement = Arrangement.spacedBy(TvTokens.SectionSpacing),
    ) {
        repeat(5) {
            TvSkeletonSection()
        }
    }
}

/**
 * 分类/视频库骨架屏 —— 海报网格。
 *
 * @param columns 每行列数。
 * @param rows 行数。
 * @param modifier 外层修饰器。
 * @param contentFocusRequester 顶部导航下探时使用的内容焦点请求器。
 */
@Composable
fun TvLibrarySkeleton(
    columns: Int = 7,
    rows: Int = 3,
    modifier: Modifier = Modifier,
    contentFocusRequester: FocusRequester? = null,
) {
    Column(
        modifier = modifier
            .loadingFocusTarget(contentFocusRequester)
            .padding(
                start = TvTokens.PageHorizontalPadding,
                end = TvTokens.PageHorizontalPadding,
            ),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        // 标题占位
        TvSkeletonTextLine(widthFraction = 0.18f)
        Spacer(modifier = Modifier.height(4.dp))
        // 副标题占位
        TvSkeletonTextLine(widthFraction = 0.35f)
        Spacer(modifier = Modifier.height(8.dp))
        // 海报网格
        repeat(rows) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(TvTokens.CardSpacing),
            ) {
                repeat(columns) {
                    TvSkeletonPoster()
                }
            }
        }
    }
}

/**
 * 通用海报网格骨架屏 —— 搜索/历史/收藏夹等列表页。
 *
 * @param columns 每行列数。
 * @param rows 行数。
 * @param modifier 外层修饰器。
 * @param contentFocusRequester 顶部导航下探时使用的内容焦点请求器。
 */
@Composable
fun TvPosterGridSkeleton(
    columns: Int = 7,
    rows: Int = 3,
    modifier: Modifier = Modifier,
    contentFocusRequester: FocusRequester? = null,
) {
    TvLibrarySkeleton(
        columns = columns,
        rows = rows,
        modifier = modifier,
        contentFocusRequester = contentFocusRequester,
    )
}

/**
 * 为可见加载骨架提供内容入口焦点目标。
 *
 * @param contentFocusRequester 顶部导航下探时使用的内容焦点请求器。
 * @return 已绑定焦点请求器的修饰器。
 */
private fun Modifier.loadingFocusTarget(contentFocusRequester: FocusRequester?): Modifier {
    if (contentFocusRequester == null) {
        return this
    }
    // 加载态没有可点击卡片时，使用可见骨架容器承接遥控器焦点。
    return focusRequester(contentFocusRequester).focusable()
}
