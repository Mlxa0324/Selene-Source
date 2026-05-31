package org.moontechlab.selene.tv.core.design.focus

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验遥控器确认键短按、长按和重复事件策略。
 */
class TvRemotePressPolicyTest {
    /**
     * 无重复事件时，抬起确认键触发一次短按。
     */
    @Test
    fun keyUpAfterInitialDown_triggersSingleShortPress() {
        val policy = TvRemotePressPolicy(hasLongPressHandler = true)

        assertThat(policy.onKeyDown(isRepeat = false)).isEqualTo(TvRemotePressAction.None)
        assertThat(policy.onKeyUp()).isEqualTo(TvRemotePressAction.ShortPress)
        assertThat(policy.onKeyUp()).isEqualTo(TvRemotePressAction.None)
    }

    /**
     * 有长按处理器时，首次重复事件只触发一次长按。
     */
    @Test
    fun repeatKeyDownWithLongPressHandler_triggersLongPressOnlyOnce() {
        val policy = TvRemotePressPolicy(hasLongPressHandler = true)

        assertThat(policy.onKeyDown(isRepeat = false)).isEqualTo(TvRemotePressAction.None)
        assertThat(policy.onKeyDown(isRepeat = true)).isEqualTo(TvRemotePressAction.LongPress)
        assertThat(policy.onKeyDown(isRepeat = true)).isEqualTo(TvRemotePressAction.None)
        assertThat(policy.onKeyUp()).isEqualTo(TvRemotePressAction.None)
    }

    /**
     * 没有长按处理器时，重复事件不应制造多次短按。
     */
    @Test
    fun repeatKeyDownWithoutLongPressHandler_doesNotDuplicateShortPress() {
        val policy = TvRemotePressPolicy(hasLongPressHandler = false)

        assertThat(policy.onKeyDown(isRepeat = false)).isEqualTo(TvRemotePressAction.None)
        assertThat(policy.onKeyDown(isRepeat = true)).isEqualTo(TvRemotePressAction.None)
        assertThat(policy.onKeyDown(isRepeat = true)).isEqualTo(TvRemotePressAction.None)
        assertThat(policy.onKeyUp()).isEqualTo(TvRemotePressAction.ShortPress)
        assertThat(policy.onKeyUp()).isEqualTo(TvRemotePressAction.None)
    }
}
