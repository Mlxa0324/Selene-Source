package org.moontechlab.selene.tv.feature.settings

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.moontechlab.selene.tv.core.network.TvMobileSettingsBridgeSession
import org.moontechlab.selene.tv.core.network.TvMobileSettingsDraft

/**
 * 校验 TV 设置状态管理契约。
 */
@OptIn(ExperimentalCoroutinesApi::class)
class TvSettingsViewModelTest {
    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setUp() {
        // ViewModel 内部使用 Dispatchers.Main.immediate，单测需注入测试调度器。
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    /**
     * 构造不启动真实扫码桥接的 ViewModel，避免 JVM 单测依赖网络与 Main 之外的副作用。
     */
    private fun createViewModel(
        initialState: TvSettingsUiState = TvSettingsUiState(),
        savePlayerKernel: suspend (String) -> String = { it },
        saveAdFilter: suspend (Boolean) -> Unit = {},
        saveImageSource: suspend (String) -> Unit = {},
        saveTheme: suspend (String) -> Unit = {},
        saveBackground: suspend (String) -> Unit = {},
    ): TvSettingsViewModel {
        return TvSettingsViewModel(
            initialState = initialState,
            savePlayerKernel = savePlayerKernel,
            saveAdFilter = saveAdFilter,
            saveImageSource = saveImageSource,
            saveTheme = saveTheme,
            saveBackground = saveBackground,
            startMobileBridge = { draft, _, _ ->
                TvMobileSettingsBridgeSession(
                    shareUri = "http://127.0.0.1:9/?draft=${draft.serverUrl}",
                    statusText = "test-bridge",
                    updateDraft = {},
                    dispose = {},
                )
            },
        )
    }

    @Test
    fun default_player_kernel_matches_persisted_storage_default() {
        val viewModel = createViewModel()

        assertThat(viewModel.state.value.playerKernelKey).isEqualTo("exo")
    }

    @Test
    fun init_prefills_server_config() {
        val viewModel = createViewModel(
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
        val viewModel = createViewModel()

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
        val viewModel = createViewModel()

        viewModel.updateDanmakuApi("https://danmaku.example.com")
        viewModel.updateDanmakuEnabled(true)

        assertThat(viewModel.state.value.danmakuApi).isEqualTo("https://danmaku.example.com")
        assertThat(viewModel.state.value.danmakuEnabled).isTrue()
    }

    @Test
    fun updateMediaOptions_updates_playback_settings() {
        val viewModel = createViewModel()

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
        val viewModel = createViewModel(
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
        val viewModel = createViewModel()

        viewModel.updateThemeKey("violet")
        viewModel.updateBackgroundKey("charcoal")
        viewModel.updateFocusEffectKey("underline")

        val state = viewModel.state.value
        assertThat(state.themeKey).isEqualTo("violet")
        assertThat(state.backgroundKey).isEqualTo("charcoal")
        assertThat(state.focusEffectKey).isEqualTo("underline")
    }

    @Test
    fun performSaveTheme_persists_selected_theme() = runTest {
        var savedTheme = ""
        val viewModel = createViewModel(
            saveTheme = { key -> savedTheme = key },
        )

        viewModel.updateThemeKey("ice_blue")
        viewModel.performSaveTheme()

        assertThat(savedTheme).isEqualTo("ice_blue")
    }

    @Test
    fun updateDanmakuSettings_updates_all_fields() {
        val viewModel = createViewModel()

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
        val viewModel = createViewModel()

        viewModel.showNotice("测试通知")
        assertThat(viewModel.state.value.noticeVisible).isTrue()
        assertThat(viewModel.state.value.noticeText).isEqualTo("测试通知")

        viewModel.dismissNotice()
        assertThat(viewModel.state.value.noticeVisible).isFalse()
    }

    /**
     * 未填齐服务器信息时，登录应失败并提示，不调用持久化回调。
     */
    @Test
    fun performSaveServerConfig_requires_complete_credentials() = runTest {
        var saved = false
        val viewModel = TvSettingsViewModel(
            initialState = TvSettingsUiState(serverUrl = "http://example.com"),
            saveServerConfig = { _, _, _ -> saved = true },
            startMobileBridge = { draft, _, _ ->
                TvMobileSettingsBridgeSession(
                    shareUri = "http://127.0.0.1:9/?draft=${draft.serverUrl}",
                    statusText = "test-bridge",
                    updateDraft = {},
                    dispose = {},
                )
            },
        )

        val ok = viewModel.performSaveServerConfig()

        assertThat(ok).isFalse()
        assertThat(saved).isFalse()
        assertThat(viewModel.state.value.noticeText).contains("请填写")
        assertThat(viewModel.state.value.savingServerConfig).isFalse()
    }

    /**
     * 完整凭据下登录成功应返回 true，并展示成功提示。
     */
    @Test
    fun performSaveServerConfig_succeeds_with_complete_credentials() = runTest {
        var savedUrl = ""
        val viewModel = TvSettingsViewModel(
            initialState = TvSettingsUiState(
                serverUrl = "http://example.com",
                account = "demo",
                password = "secret",
            ),
            saveServerConfig = { url, _, _ -> savedUrl = url },
            startMobileBridge = { draft, _, _ ->
                TvMobileSettingsBridgeSession(
                    shareUri = "http://127.0.0.1:9/?draft=${draft.serverUrl}",
                    statusText = "test-bridge",
                    updateDraft = {},
                    dispose = {},
                )
            },
        )

        val ok = viewModel.performSaveServerConfig()

        assertThat(ok).isTrue()
        assertThat(savedUrl).isEqualTo("http://example.com")
        assertThat(viewModel.state.value.noticeText).isEqualTo("登录成功")
        assertThat(viewModel.state.value.savingServerConfig).isFalse()
    }
}
