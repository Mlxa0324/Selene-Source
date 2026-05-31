package org.moontechlab.selene.tv.feature.settings

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 TV 设置状态管理契约。
 */
class TvSettingsViewModelTest {
    /**
     * 更新服务器表单时不应改动密码和弹幕状态。
     */
    @Test
    fun updateServerForm_updates_account_config_only() {
        val viewModel = TvSettingsViewModel()

        viewModel.updatePassword("secret")
        viewModel.updateDanmaku("https://danmaku.example.com", enabled = false)
        viewModel.updateServerForm("https://api.example.com", "admin")

        val state = viewModel.state.value
        assertThat(state.serverUrl).isEqualTo("https://api.example.com")
        assertThat(state.account).isEqualTo("admin")
        assertThat(state.password).isEqualTo("secret")
        assertThat(state.danmakuEnabled).isFalse()
    }

    /**
     * 更新弹幕配置时应保存服务地址和显示开关。
     */
    @Test
    fun updateDanmaku_updates_api_and_switch() {
        val viewModel = TvSettingsViewModel()

        viewModel.updateDanmaku("https://danmaku.example.com", enabled = true)

        assertThat(viewModel.state.value.danmakuApi).isEqualTo("https://danmaku.example.com")
        assertThat(viewModel.state.value.danmakuEnabled).isTrue()
    }

    /**
     * 更新媒体配置时应保存去广告、图片代理和缓存文本。
     */
    @Test
    fun updateMediaOptions_updates_playback_settings() {
        val viewModel = TvSettingsViewModel()

        viewModel.updateMediaOptions(
            adFilterEnabled = false,
            imageSource = "代理",
            cacheSizeText = "128 MB",
        )

        val state = viewModel.state.value
        assertThat(state.adFilterEnabled).isFalse()
        assertThat(state.imageSource).isEqualTo("代理")
        assertThat(state.cacheSizeText).isEqualTo("128 MB")
    }

    /**
     * 更新外观配置时应保存主题、背景和焦点效果名称。
     */
    @Test
    fun updateAppearance_updates_theme_background_and_focus() {
        val viewModel = TvSettingsViewModel()

        viewModel.updateAppearance(
            themeName = "紫色",
            backgroundName = "纯黑",
            focusEffectName = "放大",
        )

        val state = viewModel.state.value
        assertThat(state.themeName).isEqualTo("紫色")
        assertThat(state.backgroundName).isEqualTo("纯黑")
        assertThat(state.focusEffectName).isEqualTo("放大")
    }
}
