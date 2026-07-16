package org.moontechlab.selene.tv.core.design.focus

import androidx.compose.ui.input.key.Key
import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验平板/TV 确认键判定。
 */
class TvConfirmInputTest {
    @Test
    fun confirm_keys_include_enter_center_and_space() {
        assertThat(Key.Enter.isTvConfirmKey()).isTrue()
        assertThat(Key.NumPadEnter.isTvConfirmKey()).isTrue()
        assertThat(Key.DirectionCenter.isTvConfirmKey()).isTrue()
        assertThat(Key.Spacebar.isTvConfirmKey()).isTrue()
        assertThat(Key.DirectionDown.isTvConfirmKey()).isFalse()
        assertThat(Key.Back.isTvConfirmKey()).isFalse()
    }

    @Test
    fun menu_key_is_recognized() {
        assertThat(Key.Menu.isTvMenuKey()).isTrue()
        assertThat(Key.Enter.isTvMenuKey()).isFalse()
        assertThat(Key.Back.isTvMenuKey()).isFalse()
    }
}
