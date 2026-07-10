package uk.oxiang.ivy.tv.core.design.focus

import com.google.common.truth.Truth.assertThat
import org.junit.After
import org.junit.Test

/**
 * [TvDirectionalRepeatThrottle] 契约测试：方向键长按节流分组。
 *
 * 对齐 Flutter `TvFocusable._handleDirectionalRepeatThrottle`：120ms 冷却内的
 * 重复事件被吞掉，首次按下和冷却结束后的重复事件放行。
 */
class TvDirectionalRepeatThrottleTest {

    @After
    fun tearDown() {
        TvDirectionalRepeatThrottle.clear()
    }

    @Test
    fun firstKeyDown_isNeverThrottled() {
        val throttled = TvDirectionalRepeatThrottle.shouldThrottle(
            groupKey = "group-a",
            direction = TvDirection.DOWN,
            isRepeatEvent = false,
            nowNanos = 0L,
        )

        assertThat(throttled).isFalse()
    }

    @Test
    fun repeatEvent_withinCooldownWindow_isThrottled() {
        TvDirectionalRepeatThrottle.shouldThrottle(
            groupKey = "group-a",
            direction = TvDirection.DOWN,
            isRepeatEvent = false,
            nowNanos = 0L,
        )

        val throttled = TvDirectionalRepeatThrottle.shouldThrottle(
            groupKey = "group-a",
            direction = TvDirection.DOWN,
            isRepeatEvent = true,
            nowNanos = 60_000_000L, // 60ms < 120ms 默认冷却
        )

        assertThat(throttled).isTrue()
    }

    @Test
    fun repeatEvent_afterCooldownWindow_isNotThrottled() {
        TvDirectionalRepeatThrottle.shouldThrottle(
            groupKey = "group-a",
            direction = TvDirection.DOWN,
            isRepeatEvent = false,
            nowNanos = 0L,
        )

        val throttled = TvDirectionalRepeatThrottle.shouldThrottle(
            groupKey = "group-a",
            direction = TvDirection.DOWN,
            isRepeatEvent = true,
            nowNanos = 150_000_000L, // 150ms > 120ms 默认冷却
        )

        assertThat(throttled).isFalse()
    }

    @Test
    fun differentGroups_doNotShareThrottleState() {
        TvDirectionalRepeatThrottle.shouldThrottle(
            groupKey = "group-a",
            direction = TvDirection.DOWN,
            isRepeatEvent = false,
            nowNanos = 0L,
        )

        val throttledOtherGroup = TvDirectionalRepeatThrottle.shouldThrottle(
            groupKey = "group-b",
            direction = TvDirection.DOWN,
            isRepeatEvent = true,
            nowNanos = 10_000_000L,
        )

        // 不同分组互不影响，非文字列表（卡片/主导航）不启用节流即可保持原生重复速率。
        assertThat(throttledOtherGroup).isFalse()
    }

    @Test
    fun directionChange_resetsThrottleState() {
        TvDirectionalRepeatThrottle.shouldThrottle(
            groupKey = "group-a",
            direction = TvDirection.DOWN,
            isRepeatEvent = false,
            nowNanos = 0L,
        )

        val throttled = TvDirectionalRepeatThrottle.shouldThrottle(
            groupKey = "group-a",
            direction = TvDirection.UP,
            isRepeatEvent = true,
            nowNanos = 10_000_000L,
        )

        // 方向切换后视为新的按压节奏，不应该被上一次方向的冷却吞掉。
        assertThat(throttled).isFalse()
    }
}
