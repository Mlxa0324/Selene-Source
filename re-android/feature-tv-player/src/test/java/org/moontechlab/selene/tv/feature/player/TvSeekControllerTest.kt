package org.moontechlab.selene.tv.feature.player

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 TV 遥控器 seek 步进规则。
 */
class TvSeekControllerTest {
    /**
     * 长按初期保持小步进，超过阈值后再平滑加速。
     */
    @Test
    fun longPress_seek_delta_accelerates_after_threshold() {
        val controller = TvSeekController()

        assertThat(controller.computeDeltaSeconds(holdMs = 100)).isEqualTo(5)
        assertThat(controller.computeDeltaSeconds(holdMs = 2_400)).isGreaterThan(5)
    }

    /**
     * 步进最大值需要封顶，避免长按时跳动过猛。
     */
    @Test
    fun longPress_seek_delta_caps_at_max_step() {
        val controller = TvSeekController()

        assertThat(controller.computeDeltaSeconds(holdMs = 10_000)).isEqualTo(19)
    }
}
