package uk.oxiang.ivy.tv.core.design.focus

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * [TvRemotePressPolicy] 契约测试：短按/长按判定。
 *
 * 对齐 Flutter `TvFocusable` 确认键判定：`KeyDown` 记录按压键，`KeyRepeat`
 * 长按只触发一次，`KeyUp` 未触发长按才回落短按。
 */
class TvRemotePressPolicyTest {

    @Test
    fun shortPress_triggersOnKeyUp_whenNoRepeatReceived() {
        val policy = TvRemotePressPolicy(hasLongPressHandler = true)

        val downAction = policy.onKeyDown(isRepeat = false)
        val upAction = policy.onKeyUp()

        assertThat(downAction).isEqualTo(TvRemotePressAction.None)
        assertThat(upAction).isEqualTo(TvRemotePressAction.ShortPress)
    }

    @Test
    fun longPress_triggersOnce_onFirstRepeatEvent() {
        val policy = TvRemotePressPolicy(hasLongPressHandler = true)

        policy.onKeyDown(isRepeat = false)
        val firstRepeat = policy.onKeyDown(isRepeat = true)
        val secondRepeat = policy.onKeyDown(isRepeat = true)
        val upAction = policy.onKeyUp()

        assertThat(firstRepeat).isEqualTo(TvRemotePressAction.LongPress)
        assertThat(secondRepeat).isEqualTo(TvRemotePressAction.None)
        // 已经触发过长按，KeyUp 不应该再回落成短按，避免一次物理按压重复触发业务。
        assertThat(upAction).isEqualTo(TvRemotePressAction.None)
    }

    @Test
    fun repeatEvent_isIgnored_whenNoLongPressHandlerProvided() {
        val policy = TvRemotePressPolicy(hasLongPressHandler = false)

        policy.onKeyDown(isRepeat = false)
        val repeatAction = policy.onKeyDown(isRepeat = true)
        val upAction = policy.onKeyUp()

        assertThat(repeatAction).isEqualTo(TvRemotePressAction.None)
        // 没有长按处理器时，重复事件不消费按压态，抬起时仍应回落短按。
        assertThat(upAction).isEqualTo(TvRemotePressAction.ShortPress)
    }

    @Test
    fun keyUp_withoutPriorKeyDown_producesNoAction() {
        val policy = TvRemotePressPolicy(hasLongPressHandler = true)

        val upAction = policy.onKeyUp()

        assertThat(upAction).isEqualTo(TvRemotePressAction.None)
    }
}
