package org.moontechlab.selene.tv.core.data.storage

import com.google.common.truth.Truth.assertThat
import java.io.File
import kotlinx.coroutines.test.runTest
import org.junit.Test

/**
 * 校验 TV 偏好存储契约。
 */
class TvPreferencesStoreTest {
    /**
     * 播放器内核默认值为 Exo；设置页已隐藏切换入口。
     */
    @Test
    fun player_kernel_defaults_to_exo() = runTest {
        val store = TvPreferencesStore()

        assertThat(store.peekPlayerKernel()).isEqualTo("exo")
        assertThat(store.getPlayerKernel()).isEqualTo("exo")
    }

    /**
     * 播放器内核必须可保存并同步读取，供导航图首次组合避免误走默认链路。
     */
    @Test
    fun player_kernel_can_be_saved_and_peeked() = runTest {
        val store = TvPreferencesStore()

        store.savePlayerKernel("exo")

        assertThat(store.peekPlayerKernel()).isEqualTo("exo")
        assertThat(store.getPlayerKernel()).isEqualTo("exo")
    }

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

    /**
     * 播放器内核设置不能只停留在内存里，否则安装新包或进程重启后会悄悄回退到默认内核，
     * 直接干扰 Exo/WebView 真正的运行态排障。
     */
    @Test
    fun player_kernel_source_declares_persistent_backing_store() = runTest {
        val source = readStoreSource()

        assertThat(source).contains("Context? = null")
        assertThat(source).contains("getSharedPreferences(")
        assertThat(source).contains("KEY_PLAYER_KERNEL")
        assertThat(source).contains("putString(KEY_PLAYER_KERNEL")
    }

    /**
     * 读取偏好存储源码。
     *
     * @return 当前偏好存储源码文本。
     */
    private fun readStoreSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/core/data/storage/TvPreferencesStore.kt")
            .readText()
    }
}
