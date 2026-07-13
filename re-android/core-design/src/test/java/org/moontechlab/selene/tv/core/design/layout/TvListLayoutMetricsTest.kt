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
     * 横向列表左右都使用页面边距：左侧对齐标题，右侧末端收口不贴屏。
     */
    @Test
    fun railContentPadding_usesPagePaddingOnBothSides() {
        assertThat(TvListLayoutMetrics.RailStartPadding).isEqualTo(46.dp)
        assertThat(TvListLayoutMetrics.RailEndPadding).isEqualTo(46.dp)
    }

    /**
     * 海报可视列数应固定为 7，供网格和横向推荐轨道共用。
     */
    @Test
    fun posterColumns_matchesSevenColumnDensity() {
        assertThat(TvListLayoutMetrics.PosterColumns).isEqualTo(7)
    }

    /**
     * 7 列密度应按视口均分：1920 宽、左右 46、间距 18 时卡片宽约 235.4dp。
     */
    @Test
    fun resolvePosterRailItemWidth_dividesViewportBySevenColumns() {
        val width = TvListLayoutMetrics.resolvePosterRailItemWidth(
            viewportWidth = 1920.dp,
            startPadding = 46.dp,
            endPadding = 46.dp,
            spacing = 18.dp,
            columns = 7,
        )
        // (1920 - 46 - 46 - 18*6) / 7 = 1718 / 7
        val expected = (1920f - 46f - 46f - 18f * 6f) / 7f
        assertThat(width.value).isWithin(0.5f).of(expected)
        val cover = TvListLayoutMetrics.resolvePosterCoverHeight(width)
        assertThat(cover.value).isWithin(0.5f).of(width.value * 225f / 158f)
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
     * 横向海报带需要复刻 Flutter TV：同轨前 4 张不推动列表，第 5 张开始按卡片步长推进。
     *
     * 上下跨轨进入不得横向复位，只在同轨左右移动时才调用 animateScrollToItem。
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
        assertThat(railSource).contains("val isIntraRailHorizontalMove =")
        assertThat(railSource).contains("TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(")
        assertThat(railSource).contains("if (isIntraRailHorizontalMove) {")
        assertThat(railSource).contains("animateScrollToItem")
        assertThat(railSource).contains("resolveRailFirstVisibleItemIndex")
        assertThat(railSource).doesNotContain("snapshotFlow { listState.firstVisibleItemIndex }")
    }
}
