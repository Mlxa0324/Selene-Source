package org.moontechlab.selene.tv.feature.player

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 TV 遥控器 seek 步进规则。
 */
class TvSeekControllerTest {
    /**
     * 短按方向键应对齐 Flutter TV 的 10 秒跳转。
     */
    @Test
    fun shortPress_seek_delta_uses_flutter_tv_initial_step() {
        val controller = TvSeekController()

        assertThat(controller.computeDeltaSeconds(holdMs = 100L)).isEqualTo(10)
    }

    /**
     * 物理按住达到 250 毫秒后进入第一档，满 4 秒时切入第二档。
     */
    @Test
    fun longPress_seek_delta_changes_gear_at_four_physical_seconds() {
        val controller = TvSeekController()

        assertThat(controller.computeDeltaSeconds(holdMs = 250L)).isEqualTo(12)
        assertThat(controller.computeDeltaSeconds(holdMs = 3_999L)).isEqualTo(12)
        assertThat(controller.computeDeltaSeconds(holdMs = 4_000L)).isEqualTo(22)
        assertThat(controller.computeDeltaSeconds(holdMs = 10_000L)).isEqualTo(22)
    }

    /**
     * 10 秒物理按住应按现有 100 毫秒调度节拍累计跳转 1786 秒。
     */
    @Test
    fun continuousSeek_ten_second_hold_travels_about_thirty_minutes() {
        val controller = TvSeekController()
        val tickHoldTimes = generateSequence(250L) { previous -> previous + 100L }
            .takeWhile { holdMs -> holdMs < 10_000L }
            .toList()

        // 首次按下先跳转 10 秒，后续 98 次 tick 按物理按住时长选择档位。
        val totalSeconds = 10 + tickHoldTimes.sumOf(controller::computeDeltaSeconds)

        assertThat(totalSeconds).isEqualTo(1_786)
        assertThat(totalSeconds).isAtLeast(29 * 60 + 30)
        assertThat(totalSeconds).isAtMost(30 * 60 + 30)
    }

    /**
     * 展示时间的秒个位应在同一物理秒内保持稳定，跨秒后只前进一格。
     */
    @Test
    fun displayPosition_seconds_ones_advances_once_per_physical_second() {
        val controller = TvSeekController()

        val withinSameSecond = controller.computeDisplayPositionMs(
            actualPositionMs = 1_234_000L,
            basePositionMs = 300_000L,
            holdMs = 1_250L,
            direction = 1,
            durationMs = 7_200_000L,
        )
        val beforeNextSecond = controller.computeDisplayPositionMs(
            actualPositionMs = 1_244_000L,
            basePositionMs = 300_000L,
            holdMs = 1_999L,
            direction = 1,
            durationMs = 7_200_000L,
        )
        val afterNextSecond = controller.computeDisplayPositionMs(
            actualPositionMs = 1_254_000L,
            basePositionMs = 300_000L,
            holdMs = 2_250L,
            direction = 1,
            durationMs = 7_200_000L,
        )

        assertThat(withinSameSecond).isEqualTo(1_231_000L)
        assertThat(beforeNextSecond).isEqualTo(1_241_000L)
        assertThat(afterNextSecond).isEqualTo(1_252_000L)
    }

    /**
     * 连续 seek 在 250 毫秒启动时，展示秒个位必须从基准值平滑衔接。
     */
    @Test
    fun displayPosition_seconds_ones_stays_stable_when_continuous_seek_starts() {
        val controller = TvSeekController()
        val holdAndActualPositions = listOf(
            100L to 310_000L,
            250L to 321_000L,
            350L to 333_000L,
            1_249L to 444_000L,
            1_250L to 455_000L,
        )

        // 250 毫秒真实目标的秒个位故意设为 1，用于捕获展示边界回退。
        val displaySecondOnes = holdAndActualPositions.map { (holdMs, actualPositionMs) ->
            val displayPositionMs = controller.computeDisplayPositionMs(
                actualPositionMs = actualPositionMs,
                basePositionMs = 300_000L,
                holdMs = holdMs,
                direction = 1,
                durationMs = 7_200_000L,
            )
            (displayPositionMs / 1_000L) % 10L
        }

        assertThat(displaySecondOnes)
            .containsExactly(0L, 0L, 0L, 0L, 1L)
            .inOrder()
    }

    /**
     * 快退跨过秒个位零点时必须使用非负取模，避免出现负数展示位。
     */
    @Test
    fun displayPosition_rewind_uses_positive_seconds_ones_modulo() {
        val controller = TvSeekController()

        val displayPositionMs = controller.computeDisplayPositionMs(
            actualPositionMs = 294_000L,
            basePositionMs = 300_000L,
            holdMs = 1_250L,
            direction = -1,
            durationMs = 7_200_000L,
        )

        assertThat(displayPositionMs).isEqualTo(299_000L)
        assertThat((displayPositionMs / 1_000L) % 10L).isEqualTo(9L)
    }

    /**
     * 展示位置必须裁剪到视频起点和终点，不能越过有效播放范围。
     */
    @Test
    fun displayPosition_clips_to_video_start_and_end() {
        val controller = TvSeekController()

        val clippedAtStart = controller.computeDisplayPositionMs(
            actualPositionMs = -10_000L,
            basePositionMs = 0L,
            holdMs = 100L,
            direction = -1,
            durationMs = 65_000L,
        )
        val clippedAtEnd = controller.computeDisplayPositionMs(
            actualPositionMs = 90_000L,
            basePositionMs = 8_000L,
            holdMs = 1_250L,
            direction = 1,
            durationMs = 65_000L,
        )

        assertThat(clippedAtStart).isEqualTo(0L)
        assertThat(clippedAtEnd).isEqualTo(65_000L)
    }
}
