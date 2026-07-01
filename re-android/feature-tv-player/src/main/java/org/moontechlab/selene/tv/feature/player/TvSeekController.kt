package org.moontechlab.selene.tv.feature.player

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
        if (holdMs < LONG_PRESS_START_MS) {
            // 短按左右键对齐 Flutter TV，单次跳转 10 秒。
            return INITIAL_PRESS_SECONDS
        }
        val longPressElapsedMs = holdMs - LONG_PRESS_START_MS
        return if (longPressElapsedMs < ACCELERATION_THRESHOLD_MS) {
            // 长按前 5 秒每 tick 推进 12 秒，保持分钟位滚动前的可控性。
            NORMAL_REPEAT_STEP_SECONDS
        } else {
            // 长按超过 5 秒后提升到 18 秒，贴近 Flutter TV 的快速拖动手感。
            ACCELERATED_REPEAT_STEP_SECONDS
        }
    }

    /**
     * 根据真实 seek 目标计算中心提示展示时间。
     *
     * @param actualPositionMs 实际下发给播放器的 seek 目标。
     * @param basePositionMs 本轮按压开始时的展示基准位置。
     * @param holdMs 当前方向键按住时长，单位毫秒。
     * @param direction seek 方向，`1` 为快进，`-1` 为快退。
     * @param durationMs 当前视频总时长，单位毫秒。
     * @return 中心提示使用的展示位置，真实 seek 目标不受影响。
     */
    fun computeDisplayPositionMs(
        actualPositionMs: Long,
        basePositionMs: Long,
        holdMs: Long,
        direction: Int,
        durationMs: Long,
    ): Long {
        val safeActualMs = actualPositionMs.coerceInDuration(durationMs)
        if (direction == 0 || holdMs <= LONG_PRESS_START_MS || durationMs <= 0L) {
            // 短按或无有效总时长时，展示时间直接跟随真实 seek 目标。
            return safeActualMs
        }

        val actualSeconds = safeActualMs / 1_000L
        val durationSeconds = durationMs / 1_000L
        val actualSecondsInMinute = actualSeconds % 60L
        val actualSecondTens = actualSecondsInMinute / 10L
        val baseSecondOnes = (basePositionMs / 1_000L) % 10L
        val elapsedSeconds = (holdMs - LONG_PRESS_START_MS) / 1_000L
        val displaySecondOnes = positiveModulo(
            baseSecondOnes + direction * elapsedSeconds,
            SECOND_ONES_DIVISOR,
        )
        val displaySecondsInMinute = actualSecondTens * 10L + displaySecondOnes
        val displaySeconds = (actualSeconds / 60L) * 60L + displaySecondsInMinute
        return displaySeconds.coerceIn(0L, durationSeconds) * 1_000L
    }

    /**
     * 将毫秒位置裁剪到视频时长内。
     *
     * @param durationMs 当前视频总时长。
     * @return 安全播放位置。
     */
    private fun Long.coerceInDuration(durationMs: Long): Long {
        return if (durationMs > 0L) {
            coerceIn(0L, durationMs)
        } else {
            coerceAtLeast(0L)
        }
    }

    /**
     * 对负向快退场景做安全取模。
     *
     * @param value 待取模的数值。
     * @param divisor 模数。
     * @return 非负取模结果。
     */
    private fun positiveModulo(
        value: Long,
        divisor: Long,
    ): Long {
        val result = value % divisor
        return if (result < 0L) result + divisor else result
    }

    private companion object {
        /** 短按方向键时的 seek 秒数。 */
        const val INITIAL_PRESS_SECONDS = 10

        /** 长按第一档每个 tick 推进的视频秒数。 */
        const val NORMAL_REPEAT_STEP_SECONDS = 12

        /** 长按第二档每个 tick 推进的视频秒数。 */
        const val ACCELERATED_REPEAT_STEP_SECONDS = 18

        /** 短按和长按的分界时间。 */
        const val LONG_PRESS_START_MS = 250L

        /** 长按切入第二段加速的持续时间阈值。 */
        const val ACCELERATION_THRESHOLD_MS = 5_000L

        /** 秒个位的取模基数。 */
        const val SECOND_ONES_DIVISOR = 10L
    }
}
