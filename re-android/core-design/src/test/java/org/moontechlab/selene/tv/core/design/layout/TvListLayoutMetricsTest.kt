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
     * 页面级横滑：左 = pageGutter；右 = start + 2×focusSafe（末端停靠大于左侧）。
     */
    @Test
    fun railContentPadding_endIsStartPlusFocusSafe() {
        assertThat(TvListLayoutMetrics.RailStartPadding).isEqualTo(50.dp)
        assertThat(TvListLayoutMetrics.FocusSafePadding).isEqualTo(10.dp)
        assertThat(TvListLayoutMetrics.RailEndPadding)
            .isEqualTo(50.dp + 10.dp * 2)
    }

    /**
     * 面板内横滑末端 inset：2×start + focusSafe。
     */
    @Test
    fun embeddedShelfEndInset_isTwiceStartPlusFocusSafe() {
        assertThat(TvListLayoutMetrics.embeddedShelfEndInset(22.dp))
            .isEqualTo(22.dp * 2 + 10.dp)
    }

    /**
     * 海报可视列数应固定为 7，供网格和横向推荐轨道共用。
     */
    @Test
    fun posterColumns_matchesSevenColumnDensity() {
        assertThat(TvListLayoutMetrics.PosterColumns).isEqualTo(7)
    }

    /**
     * 7 列密度应按视口均分：1920 宽、左右 50、间距 18 时卡片宽可算。
     */
    @Test
    fun resolvePosterRailItemWidth_dividesViewportBySevenColumns() {
        val width = TvListLayoutMetrics.resolvePosterRailItemWidth(
            viewportWidth = 1920.dp,
            startPadding = 50.dp,
            endPadding = 50.dp,
            spacing = 18.dp,
            columns = 7,
        )
        // (1920 - 50 - 50 - 18*6) / 7
        val expected = (1920f - 50f - 50f - 18f * 6f) / 7f
        assertThat(width.value).isWithin(0.5f).of(expected)
        val cover = TvListLayoutMetrics.resolvePosterCoverHeight(width)
        assertThat(cover.value).isWithin(0.5f).of(width.value * 225f / 158f)
    }

    /**
     * 纵向网格左右对齐页面标题，统一使用页面水平边距。
     */
    @Test
    fun gridContentPadding_usesPageHorizontalPaddingInsidePageScaffold() {
        assertThat(TvListLayoutMetrics.GridHorizontalPadding).isEqualTo(50.dp)
        assertThat(TvListLayoutMetrics.GridBottomPadding).isEqualTo(32.dp)
    }

    /**
     * 横向海报带：中段 pin-leading；末项 ensureTrailingGapVisible；不 clip 获焦放大。
     */
    @Test
    fun railFocusScroll_usesFlutterHomeSectionScrollRule() {
        val metricsSource = File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvListLayoutMetrics.kt")
            .readText()
        val railSource = File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvPosterRail.kt")
            .readText()
        val edgeSource = File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvEdgeScroll.kt")
            .readText()

        assertThat(metricsSource).contains("RailScrollStartIndex = 4")
        assertThat(metricsSource).contains("resolveRailFirstVisibleItemIndex")
        assertThat(metricsSource).contains("embeddedShelfEndInset")
        assertThat(railSource).contains("onFocusChanged = { hasFocus ->")
        assertThat(railSource).contains("val isIntraRailHorizontalMove =")
        assertThat(railSource).contains("TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(")
        assertThat(railSource).contains("if (isIntraRailHorizontalMove) {")
        assertThat(railSource).contains("animateScrollToItem")
        assertThat(railSource).contains("resolveRailFirstVisibleItemIndex")
        assertThat(railSource).contains("ensureTrailingGapVisible")
        assertThat(railSource).contains("graphicsLayer { clip = false }")
        assertThat(edgeSource).contains("ensureTrailingGapVisible")
        assertThat(edgeSource).contains("tvBleedContentStart")
        assertThat(railSource).doesNotContain("snapshotFlow { listState.firstVisibleItemIndex }")
    }
}
