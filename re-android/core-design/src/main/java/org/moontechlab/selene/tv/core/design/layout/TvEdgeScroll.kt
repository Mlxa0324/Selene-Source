package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * TV 边缘停靠与视口辅助。
 *
 * ## 概念（Edge Settling Inset）
 * 滚到顶/底/最左/最右**停稳**时，保证首尾项（含焦点态）完整可见的预留。
 * 中段滚动允许贴边、探头；与页面 gutter、焦点安全距分角色使用。
 *
 * ## 三层
 * 1. Viewport：尽量贴容器缘
 * 2. Content inset（Lazy contentPadding）：停靠位置
 * 3. Focus safe：描边 + scale 溢出
 */
object TvEdgeScroll {
    /**
     * 末项（或指定项）获焦后，补滚使「项右缘到视口右缘」≥ [desiredEndGapPx]。
     *
     * 解决 pin-to-leading 滚不到 max、end contentPadding 留在屏外的问题。
     *
     * @param itemIndex 目标项 0-based 下标。
     * @param desiredEndGapPx 期望的右缘空隙（end inset + focus 溢出，像素）。
     */
    suspend fun LazyListState.ensureTrailingGapVisible(
        itemIndex: Int,
        desiredEndGapPx: Int,
    ) {
        if (desiredEndGapPx <= 0 || itemIndex < 0) {
            return
        }
        val info = layoutInfo
        val item = info.visibleItemsInfo.lastOrNull { visible ->
            visible.index == itemIndex
        } ?: return
        val endGap = info.viewportEndOffset - (item.offset + item.size)
        val delta = desiredEndGapPx - endGap
        if (delta > 0) {
            animateScrollBy(delta.toFloat())
        }
    }
}

/**
 * 仅向**左**外扩 [bleed]，用于父级已有对称水平 padding 的横滑轨。
 *
 * - 左：可滑入父级 padding 区，静止时 start contentPadding 仍与标题对齐
 * - 右：**不外扩**，end contentPadding 留在内容宽度内，末端才能真正露出
 *
 * 禁止用负 [Modifier.padding]（Compose 要求 ≥ 0）。
 *
 * @param bleed 左侧外扩量（通常等于父级 horizontal padding）。
 */
fun Modifier.tvBleedContentStart(bleed: Dp): Modifier {
    if (bleed <= 0.dp) {
        return this
    }
    return layout { measurable, constraints ->
        val bleedPx = bleed.roundToPx().coerceAtLeast(0)
        val expandedMaxWidth = (constraints.maxWidth + bleedPx).coerceAtLeast(0)
        val placeable = measurable.measure(
            constraints.copy(
                minWidth = 0,
                maxWidth = expandedMaxWidth,
            ),
        )
        layout(constraints.maxWidth, placeable.height) {
            placeable.placeRelative(-bleedPx, 0)
        }
    }
}
