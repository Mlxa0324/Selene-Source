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

        assertThat(controller.computeDeltaSeconds(holdMs = 100)).isEqualTo(10)
    }

    /**
     * 长按前 5 秒应使用 Flutter TV 第一档 12 秒 tick。
     */
    @Test
    fun longPress_seek_delta_uses_normal_repeat_step_before_threshold() {
        val controller = TvSeekController()

        assertThat(controller.computeDeltaSeconds(holdMs = 1_000)).isEqualTo(12)
        assertThat(controller.computeDeltaSeconds(holdMs = 5_000)).isEqualTo(12)
    }

    /**
     * 长按 5 秒后应使用 Flutter TV 第二档 18 秒 tick。
     */
    @Test
    fun longPress_seek_delta_uses_accelerated_repeat_step_after_threshold() {
        val controller = TvSeekController()

        assertThat(controller.computeDeltaSeconds(holdMs = 5_500)).isEqualTo(18)
        assertThat(controller.computeDeltaSeconds(holdMs = 10_000)).isEqualTo(18)
    }
}
