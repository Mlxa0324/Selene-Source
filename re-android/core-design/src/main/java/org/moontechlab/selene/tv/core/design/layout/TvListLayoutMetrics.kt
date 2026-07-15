package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 列表布局指标。
 */
object TvListLayoutMetrics {
    /**
     * TV 海报可视列数。
     *
     * 首页网格、历史、收藏和详情相关推荐统一按 7 列密度排布，
     * 避免各页面各自写死导致可视卡片数不一致。
     */
    const val PosterColumns = 7

    /**
     * 横向海报带开始推动列表的 0-based 卡片下标。
     *
     * Flutter TV 首页约定前 4 张卡片保持原位，第 5 张获焦才开始横向推进。
     */
    const val RailScrollStartIndex = 4

    /**
     * 海报获焦放大后的边界安全留白。
     */
    val FocusSafePadding = 10.dp

    /**
     * 横向列表左侧首张卡片距屏幕左边缘的缩进，滚动后可贴边。
     */
    val RailStartPadding = TvTokens.PageHorizontalPadding

    /**
     * 横向列表右侧收口留白。
     *
     * 与左侧页面边距一致：默认浏览时内容仍可从右缘进出，
     * 滚到最右侧时末卡不会贴死屏幕边框。
     */
    val RailEndPadding = TvTokens.PageHorizontalPadding

    /**
     * 纵向网格左右安全留白。
     */
    val GridHorizontalPadding = TvTokens.PageHorizontalPadding

    /**
     * 纵向网格底部安全留白。
     *
     * 须覆盖海报标题+副标题两行文案高度，否则末行/近底行获焦时标题被视口裁掉
     *（分类/历史/收藏等 Grid 页；首页横轨不受影响）。
     */
    val GridBottomPadding = 72.dp

    /**
     * 海报封面下方标题区最小高度（标题+副标题+间距）。
     *
     * 网格项测量必须计入该高度，跟滚才能把「整卡」滚进视口，而不是只露出封面。
     */
    val PosterTitleBlockHeight = 56.dp

    /**
     * 按可视列数计算横向海报卡片宽度。
     *
     * 视口宽度扣除左右 contentPadding 与列间距后均分，
     * 用于详情相关推荐等需要“首屏刚好 N 列”的轨道。
     *
     * @param viewportWidth 当前列表视口宽度。
     * @param startPadding 左侧 contentPadding。
     * @param endPadding 右侧 contentPadding。
     * @param spacing 卡片间距。
     * @param columns 可视列数，默认 [PosterColumns]。
     * @return 单张卡片宽度，至少 1.dp。
     */
    fun resolvePosterRailItemWidth(
        viewportWidth: Dp,
        startPadding: Dp = RailStartPadding,
        endPadding: Dp = RailEndPadding,
        spacing: Dp = TvTokens.CardSpacing,
        columns: Int = PosterColumns,
    ): Dp {
        val safeColumns = columns.coerceAtLeast(1)
        val gapTotal = spacing * (safeColumns - 1)
        val available = viewportWidth - startPadding - endPadding - gapTotal
        return (available / safeColumns).coerceAtLeast(1.dp)
    }

    /**
     * 按海报封面宽高比换算封面高度。
     *
     * @param cardWidth 卡片宽度。
     * @return 封面高度，保持与 [TvTokens.PosterWidth]/[TvTokens.PosterCoverHeight] 一致。
     */
    fun resolvePosterCoverHeight(
        cardWidth: Dp,
    ): Dp {
        // 225/158 ≈ 1.424，相关推荐与首页海报封面比例统一。
        val ratio = TvTokens.PosterCoverHeight.value / TvTokens.PosterWidth.value
        return cardWidth * ratio
    }

    /**
     * 计算横向海报带焦点卡片对应的首个可见卡片下标。
     *
     * @param focusedIndex 当前获焦卡片下标。
     * @param itemCount 当前列表可见项目总数。
     * @return 目标首个可见项目下标。
     */
    fun resolveRailFirstVisibleItemIndex(
        focusedIndex: Int,
        itemCount: Int,
    ): Int {
        if (focusedIndex < RailScrollStartIndex || itemCount <= 0) {
            // 前 4 张维持首屏静止，贴近 Flutter TV 首页横向浏览节奏。
            return 0
        }
        val lastIndex = itemCount - 1
        return (focusedIndex - RailScrollStartIndex + 1)
            .coerceIn(0, lastIndex)
    }
}
