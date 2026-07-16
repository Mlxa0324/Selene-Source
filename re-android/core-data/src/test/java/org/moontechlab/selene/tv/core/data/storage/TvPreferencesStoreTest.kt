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
     * 外观设置（主题色/图片代理/去广告）必须可保存并同步 peek，供设置页回填与壳层立即生效。
     */
    @Test
    fun appearance_settings_can_be_saved_and_peeked() = runTest {
        val store = TvPreferencesStore()

        store.saveThemeKey("violet")
        store.saveBackgroundKey("charcoal")
        store.saveImageSource("tencent_cdn")
        store.saveAdFilterEnabled(false)

        assertThat(store.peekThemeKey()).isEqualTo("violet")
        assertThat(store.peekBackgroundKey()).isEqualTo("charcoal")
        assertThat(store.peekImageSource()).isEqualTo("tencent_cdn")
        assertThat(store.peekAdFilterEnabled()).isFalse()
        assertThat(store.peekAppearance().themeKey).isEqualTo("violet")
        assertThat(store.peekAppearance().imageSource).isEqualTo("tencent_cdn")
    }

    /**
     * 外观字段必须声明 SharedPreferences 持久化键，避免只改内存导致重启丢失。
     */
    @Test
    fun appearance_source_declares_persistent_backing_store() = runTest {
        val source = readStoreSource()

        assertThat(source).contains("KEY_THEME_KEY")
        assertThat(source).contains("KEY_IMAGE_SOURCE")
        assertThat(source).contains("KEY_AD_FILTER_ENABLED")
        assertThat(source).contains("putString(KEY_THEME_KEY")
        assertThat(source).contains("putString(KEY_IMAGE_SOURCE")
        assertThat(source).contains("putBoolean(KEY_AD_FILTER_ENABLED")
        assertThat(source).contains("DEFAULT_THEME_KEY = TvAppearancePreferences.DEFAULT_THEME_KEY")
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
