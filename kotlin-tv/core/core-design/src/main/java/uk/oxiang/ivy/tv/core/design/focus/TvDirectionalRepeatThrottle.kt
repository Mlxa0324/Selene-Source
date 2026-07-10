package uk.oxiang.ivy.tv.core.design.focus

/**
 * TV 方向键长按节流分组注册表。
 *
 * 对齐 Flutter `TvFocusable._handleDirectionalRepeatThrottle`：纯文字列表长按
 * 方向键时按分组节流重复事件（默认 120ms），避免跳过中间选中态；卡片网格/
 * 主导航/播放器菜单等非文字列表不启用节流（不传分组 key 即可）。
 */
object TvDirectionalRepeatThrottle {
    /** 分组内最近一次方向事件状态。 */
    private data class RepeatState(val direction: TvDirection, val timestampNanos: Long)

    private val states = mutableMapOf<Any, RepeatState>()

    /**
     * 判断当前方向键重复事件是否应该被节流吞掉。
     *
     * @param groupKey 节流分组标识。
     * @param direction 当前方向键。
     * @param isRepeatEvent 是否为系统重复按键事件（非首次按下）。
     * @param nowNanos 当前时间戳（纳秒），便于测试注入。
     * @param throttleDurationNanos 节流时长（纳秒），默认对齐 Flutter 120ms。
     * @return `true` 表示本次事件应被消费（吞掉），不再向下传递。
     */
    fun shouldThrottle(
        groupKey: Any,
        direction: TvDirection,
        isRepeatEvent: Boolean,
        nowNanos: Long,
        throttleDurationNanos: Long = DEFAULT_THROTTLE_DURATION_NANOS,
    ): Boolean {
        val previous = states[groupKey]
        val isRepeatWithinCooldown = isRepeatEvent &&
            previous != null &&
            previous.direction == direction &&
            (nowNanos - previous.timestampNanos) < throttleDurationNanos

        if (isRepeatWithinCooldown) {
            return true
        }

        states[groupKey] = RepeatState(direction = direction, timestampNanos = nowNanos)
        return false
    }

    /**
     * 清空节流状态，主要供单元测试重置全局状态使用。
     */
    fun clear() {
        states.clear()
    }

    /** 默认节流时长，对齐 Flutter `directionalRepeatThrottleDuration` 默认 120ms。 */
    const val DEFAULT_THROTTLE_DURATION_NANOS = 120_000_000L
}

/**
 * TV 方向键枚举，独立于 Compose `Key`，方便节流逻辑做纯函数单元测试。
 */
enum class TvDirection {
    UP, DOWN, LEFT, RIGHT
}
