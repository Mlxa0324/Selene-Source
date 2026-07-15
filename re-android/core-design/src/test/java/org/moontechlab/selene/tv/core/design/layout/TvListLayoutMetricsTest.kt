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
        assertThat(TvListLayoutMetrics.RailStartPadding).isEqualTo(50.dp)
        assertThat(TvListLayoutMetrics.RailEndPadding).isEqualTo(50.dp)
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
        // 底边距须容纳标题+副标题，避免近底行标题被裁。
        assertThat(TvListLayoutMetrics.GridBottomPadding).isEqualTo(64.dp)
    }

    /**
     * 横向海报带：同轨左右才跟滚；中心带 scrollBy，禁止 pin firstVisible。
     * 上下跨轨进入不得横向复位。
     */
    @Test
    fun railFocusScroll_usesCenterBandFollowForIntraRailMoves() {
        val railSource = File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvPosterRail.kt")
            .readText()

        assertThat(railSource).contains("onFocusChanged = { hasFocus ->")
        assertThat(railSource).contains("val isIntraRailHorizontalMove =")
        assertThat(railSource).contains("TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(")
        assertThat(railSource).contains("if (isIntraRailHorizontalMove) {")
        assertThat(railSource).contains("scrollFocusedItemWithCenterBand")
        assertThat(railSource).contains("animateScrollBy")
        assertThat(railSource).contains("itemCenter > centerLine")
        assertThat(railSource).contains("itemCenter < centerLine")
        assertThat(railSource).doesNotContain("resolveRailFirstVisibleItemIndex")
        assertThat(railSource).doesNotContain("snapshotFlow { listState.firstVisibleItemIndex }")
    }
}
