package org.moontechlab.selene.tv.feature.settings

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test

/**
 * 校验 TV 设置状态管理契约。
 */
class TvSettingsViewModelTest {
    @Test
    fun default_player_kernel_matches_persisted_storage_default() {
        val viewModel = TvSettingsViewModel()

        assertThat(viewModel.state.value.playerKernelKey).isEqualTo("webview")
    }

    @Test
    fun init_prefills_server_config() {
        val viewModel = TvSettingsViewModel(
            initialState = TvSettingsUiState(
                serverUrl = "http://127.0.0.1:3000",
                account = "demo",
                password = "secret",
            ),
        )

        val state = viewModel.state.value
        assertThat(state.serverUrl).isEqualTo("http://127.0.0.1:3000")
        assertThat(state.account).isEqualTo("demo")
        assertThat(state.password).isEqualTo("secret")
    }

    @Test
    fun updateServerConfig_updates_account_config() {
        val viewModel = TvSettingsViewModel()

        viewModel.updatePassword("secret")
        viewModel.updateDanmakuEnabled(false)
        viewModel.updateDanmakuApi("https://danmaku.example.com")
        viewModel.updateServerUrl("https://api.example.com")
        viewModel.updateAccount("admin")

        val state = viewModel.state.value
        assertThat(state.serverUrl).isEqualTo("https://api.example.com")
        assertThat(state.account).isEqualTo("admin")
        assertThat(state.password).isEqualTo("secret")
        assertThat(state.danmakuEnabled).isFalse()
    }

    @Test
    fun updateDanmaku_updates_api_and_switch() {
        val viewModel = TvSettingsViewModel()

        viewModel.updateDanmakuApi("https://danmaku.example.com")
        viewModel.updateDanmakuEnabled(true)

        assertThat(viewModel.state.value.danmakuApi).isEqualTo("https://danmaku.example.com")
        assertThat(viewModel.state.value.danmakuEnabled).isTrue()
    }

    @Test
    fun updateMediaOptions_updates_playback_settings() {
        val viewModel = TvSettingsViewModel()

        viewModel.updateAdFilterEnabled(false)
        viewModel.updateImageSourceKey("tencent_cdn")

        val state = viewModel.state.value
        assertThat(state.adFilterEnabled).isFalse()
        assertThat(state.imageSourceKey).isEqualTo("tencent_cdn")
    }

    /**
     * 运行时解析后的真实内核必须回灌到设置状态，
     * 避免用户选了 WebView 但当前环境实际已经自动切到 Exo。
     */
    @Test
    fun performSavePlayerKernel_updates_state_with_effective_kernel() = runTest {
        var savedKernel = ""
        val viewModel = TvSettingsViewModel(
            initialState = TvSettingsUiState(playerKernelKey = "webview"),
            savePlayerKernel = { kernel ->
                savedKernel = kernel
                "exo"
            },
        )

        viewModel.performSavePlayerKernel()

        assertThat(savedKernel).isEqualTo("webview")
        assertThat(viewModel.state.value.playerKernelKey).isEqualTo("exo")
    }

    @Test
    fun updateAppearance_updates_theme_background_and_focus() {
        val viewModel = TvSettingsViewModel()

        viewModel.updateThemeKey("amber")
        viewModel.updateBackgroundKey("pure_black")
        viewModel.updateFocusEffectKey("underline")

        val state = viewModel.state.value
        assertThat(state.themeKey).isEqualTo("amber")
        assertThat(state.backgroundKey).isEqualTo("pure_black")
        assertThat(state.focusEffectKey).isEqualTo("underline")
    }

    @Test
    fun updateDanmakuSettings_updates_all_fields() {
        val viewModel = TvSettingsViewModel()

        viewModel.updateDanmakuOpacity(0.5f)
        viewModel.updateDanmakuFontScale(1.5f)
        viewModel.updateDanmakuDisplayArea(0.75f)
        viewModel.updateDanmakuPreventOverlap(false)
        viewModel.updateDanmakuSyncVideoSpeed(true)

        val state = viewModel.state.value
        assertThat(state.danmakuOpacity).isEqualTo(0.5f)
        assertThat(state.danmakuFontScale).isEqualTo(1.5f)
        assertThat(state.danmakuDisplayArea).isEqualTo(0.75f)
        assertThat(state.danmakuPreventOverlap).isFalse()
        assertThat(state.danmakuSyncVideoSpeed).isTrue()
    }

    @Test
    fun notice_shows_and_dismisses() {
        val viewModel = TvSettingsViewModel()

        viewModel.showNotice("测试通知")
        assertThat(viewModel.state.value.noticeVisible).isTrue()
        assertThat(viewModel.state.value.noticeText).isEqualTo("测试通知")

        viewModel.dismissNotice()
        assertThat(viewModel.state.value.noticeVisible).isFalse()
    }
}
