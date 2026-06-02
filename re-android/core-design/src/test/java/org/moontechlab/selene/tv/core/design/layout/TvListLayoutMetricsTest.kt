package org.moontechlab.selene.tv.core.design.layout

import androidx.compose.ui.unit.dp
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 TV 横向列表和纵向网格的安全留白契约。
 */
class TvListLayoutMetricsTest {
    /**
     * 横向列表首尾只预留焦点放大安全区，不重复叠加页面安全边距。
     */
    @Test
    fun railContentPadding_usesFocusSafePaddingWithoutPagePaddingDuplication() {
        assertThat(TvListLayoutMetrics.RailStartPadding).isEqualTo(10.dp)
        assertThat(TvListLayoutMetrics.RailEndPadding).isEqualTo(10.dp)
    }

    /**
     * 纵向网格在页面壳内只预留焦点安全区，避免首列被二次缩进。
     */
    @Test
    fun gridContentPadding_usesFocusSafePaddingInsidePageScaffold() {
        assertThat(TvListLayoutMetrics.GridHorizontalPadding).isEqualTo(10.dp)
        assertThat(TvListLayoutMetrics.GridBottomPadding).isEqualTo(32.dp)
    }
}
