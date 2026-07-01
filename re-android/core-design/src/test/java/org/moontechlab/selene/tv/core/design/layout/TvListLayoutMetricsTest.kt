package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.ui.unit.dp
import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 横向列表和纵向网格的安全留白契约。
 */
class TvListLayoutMetricsTest {
    /**
     * 横向列表左侧首卡缩进对齐页面标题，右侧贴边不留 margin。
     */
    @Test
    fun railContentPadding_usesPagePaddingStart_zeroEndForEdgeToEdge() {
        assertThat(TvListLayoutMetrics.RailStartPadding).isEqualTo(46.dp)
        assertThat(TvListLayoutMetrics.RailEndPadding).isEqualTo(0.dp)
    }

    /**
     * 纵向网格左右对齐页面标题，统一使用页面水平边距。
     */
    @Test
    fun gridContentPadding_usesPageHorizontalPaddingInsidePageScaffold() {
        assertThat(TvListLayoutMetrics.GridHorizontalPadding).isEqualTo(46.dp)
        assertThat(TvListLayoutMetrics.GridBottomPadding).isEqualTo(32.dp)
    }

    /**
     * 横向海报带需要复刻 Flutter TV：首页前 4 张不推动列表，第 5 张开始按卡片步长推进。
     */
    @Test
    fun railFocusScroll_usesFlutterHomeSectionScrollRule() {
        val metricsSource = File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvListLayoutMetrics.kt")
            .readText()
        val railSource = File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvPosterRail.kt")
            .readText()

        assertThat(metricsSource).contains("RailScrollStartIndex = 4")
        assertThat(metricsSource).contains("resolveRailFirstVisibleItemIndex")
        assertThat(metricsSource).contains("focusedIndex - RailScrollStartIndex + 1")
        assertThat(railSource).contains("onFocusChanged = { hasFocus ->")
        assertThat(railSource).contains("animateScrollToItem")
        assertThat(railSource).contains("resolveRailFirstVisibleItemIndex")
        assertThat(railSource).doesNotContain("snapshotFlow { listState.firstVisibleItemIndex }")
    }
}
