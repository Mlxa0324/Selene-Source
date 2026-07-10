package uk.oxiang.ivy.tv.core.design.layout

import androidx.compose.ui.unit.dp
import uk.oxiang.ivy.tv.core.design.TvTokens

/**
 * TV 列表布局指标。
 */
object TvListLayoutMetrics {
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
     * 横向列表右侧贴边，滚动到最后一张卡片可贴紧屏幕右边缘。
     */
    val RailEndPadding = 0.dp

    /**
     * 纵向网格左右安全留白。
     */
    val GridHorizontalPadding = TvTokens.PageHorizontalPadding

    /**
     * 纵向网格底部安全留白。
     */
    val GridBottomPadding = TvTokens.PageBottomPadding

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
