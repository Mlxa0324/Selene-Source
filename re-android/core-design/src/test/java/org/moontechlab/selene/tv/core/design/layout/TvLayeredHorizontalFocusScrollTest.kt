package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 多层横向列表焦点滚动策略契约。
 */
class TvLayeredHorizontalFocusScrollTest {
    /**
     * 上下跨层进入（无会话活跃下标）不得触发横向滚动。
     */
    @Test
    fun shouldAnimateHorizontalScroll_false_when_no_active_index() {
        assertThat(
            TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                previousActiveIndex = TvLayeredHorizontalFocusScroll.NoActiveIndex,
                newlyFocusedIndex = 3,
            ),
        ).isFalse()
    }

    /**
     * 同轨左右相邻一步才允许横向推进。
     */
    @Test
    fun shouldAnimateHorizontalScroll_true_only_for_adjacent_step() {
        assertThat(
            TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                previousActiveIndex = 2,
                newlyFocusedIndex = 3,
            ),
        ).isTrue()
        assertThat(
            TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                previousActiveIndex = 4,
                newlyFocusedIndex = 3,
            ),
        ).isTrue()
        assertThat(
            TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(
                previousActiveIndex = 1,
                newlyFocusedIndex = 4,
            ),
        ).isFalse()
    }

    /**
     * 海报轨与详情/播放器多层列表都必须复用该策略，避免上下切换把横向 offset 复位。
     */
    @Test
    fun layered_lists_share_keep_offset_policy() {
        val policy = File(
            "src/main/java/org/moontechlab/selene/tv/core/design/layout/TvLayeredHorizontalFocusScroll.kt",
        ).readText()
        val rail = File(
            "src/main/java/org/moontechlab/selene/tv/core/design/layout/TvPosterRail.kt",
        ).readText()

        assertThat(policy).contains("fun shouldAnimateHorizontalScroll(")
        assertThat(policy).contains("abs(newlyFocusedIndex - previousActiveIndex) == 1")
        assertThat(rail).contains("TvLayeredHorizontalFocusScroll.shouldAnimateHorizontalScroll(")
        assertThat(rail).contains("activeFocusedIndex = TvLayeredHorizontalFocusScroll.NoActiveIndex")
        assertThat(rail).contains("onVerticalEnter = {")
    }
}
