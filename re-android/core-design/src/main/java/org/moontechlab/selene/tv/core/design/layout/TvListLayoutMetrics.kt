package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.ui.unit.dp
import org.moontechlab.selene.tv.core.design.TvTokens

/**
 * TV 列表布局指标。
 */
object TvListLayoutMetrics {
    /**
     * 海报获焦放大后的边界安全留白。
     */
    val FocusSafePadding = 10.dp

    /**
     * 横向列表左侧安全留白。
     */
    val RailStartPadding = FocusSafePadding

    /**
     * 横向列表右侧安全留白。
     */
    val RailEndPadding = FocusSafePadding

    /**
     * 纵向网格左右安全留白。
     */
    val GridHorizontalPadding = FocusSafePadding

    /**
     * 纵向网格底部安全留白。
     */
    val GridBottomPadding = TvTokens.PageBottomPadding
}
