package org.moontechlab.selene.tv.core.data.storage

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test

/**
 * 校验 TV 偏好存储契约。
 */
class TvPreferencesStoreTest {
    /**
     * 片头片尾跳过秒数必须可保存并读取，供全屏播放器菜单复用。
     */
    @Test
    fun skip_durations_can_be_saved_and_read() = runTest {
        val store = TvPreferencesStore()

        store.saveSkipIntroSeconds(35)
        store.saveSkipOutroSeconds(29)

        assertThat(store.getSkipIntroSeconds()).isEqualTo(35)
        assertThat(store.getSkipOutroSeconds()).isEqualTo(29)
    }

    /**
     * 片头片尾跳过秒数默认值必须为 0，避免首次进入播放器误跳转。
     */
    @Test
    fun skip_durations_default_to_zero() = runTest {
        val store = TvPreferencesStore()

        assertThat(store.getSkipIntroSeconds()).isEqualTo(0)
        assertThat(store.getSkipOutroSeconds()).isEqualTo(0)
    }
}
