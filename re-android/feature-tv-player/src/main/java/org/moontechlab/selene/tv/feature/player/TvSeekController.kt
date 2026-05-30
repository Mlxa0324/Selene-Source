package org.moontechlab.selene.tv.feature.player

import kotlin.math.roundToInt

/**
 * TV 遥控器 seek 步进控制器。
 */
class TvSeekController {
    /**
     * 根据按住时长计算 seek 步进秒数。
     *
     * @param holdMs 当前方向键按住时长，单位毫秒。
     * @return 本次 seek 步进秒数。
     */
    fun computeDeltaSeconds(holdMs: Long): Int {
        if (holdMs <= ACCELERATION_START_MS) {
            // 长按初期固定小步进，减少刚开始拖动时的跳动感。
            return MIN_STEP_SECONDS
        }

        val acceleratedMs = (holdMs - ACCELERATION_START_MS).coerceAtLeast(0L)
        val ratio = (acceleratedMs.toFloat() / ACCELERATION_WINDOW_MS).coerceIn(0f, 1f)
        val delta = MIN_STEP_SECONDS + ((MAX_STEP_SECONDS - MIN_STEP_SECONDS) * ratio).roundToInt()
        // 长按后期封顶，避免持续按键直接跳过太多内容。
        return delta.coerceIn(MIN_STEP_SECONDS, MAX_STEP_SECONDS)
    }

    private companion object {
        /** 初始固定小步进秒数。 */
        const val MIN_STEP_SECONDS = 5

        /** 最大 seek 步进秒数。 */
        const val MAX_STEP_SECONDS = 19

        /** 开始加速前的按住时长阈值。 */
        const val ACCELERATION_START_MS = 500L

        /** 从最小步进加速到最大步进的时间窗口。 */
        const val ACCELERATION_WINDOW_MS = 3_000L
    }
}
