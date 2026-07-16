package org.moontechlab.selene.tv.feature.settings

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * TV 设置页焦点契约测试。
 */
class TvSettingsRouteFocusContractTest {
    /**
     * 密码行必须启用密码模式（默认星花 + 眼睛切换）。
     */
    @Test
    fun password_field_uses_password_mask_mode() {
        val source = readRouteSource()
        assertThat(source).contains("label = \"密码\"")
        assertThat(source).contains("isPassword = true")
    }

    /**
     * 服务器主操作按钮文案为「登录」，与首页「去登录」语义一致。
     */
    @Test
    fun server_primary_action_is_login() {
        val source = readRouteSource()
        assertThat(source).contains("登录中...")
        assertThat(source).contains("\"登录\"")
        assertThat(source).contains("title = \"账号登录\"")
        assertThat(source).doesNotContain("保存配置")
    }

    /**
     * 设置页首焦点落在服务器地址，并提供线性上下链与获焦滚动。
     */
    @Test
    fun route_source_assigns_first_focus_to_server_url() {
        val source = readRouteSource()

        assertThat(source).contains("import androidx.compose.ui.focus.FocusRequester")
        assertThat(source).contains("settingsEntryFocusRequester.requestFocus()")
        // 首焦只在首次进入请求一次，避免选项确认后重组再次抢回顶部。
        assertThat(source).contains("LaunchedEffect(Unit)")
        assertThat(source).doesNotContain("LaunchedEffect(settingsEntryFocusRequester)")
        assertThat(source).contains("focusAndScroll")
        assertThat(source).contains("scrollAnchorIntoView")
        assertThat(source).contains("computeSettingsFocusScrollTarget")
        assertThat(source).contains("positionInRoot()")
        assertThat(source).contains("regenerateModifier = Modifier.trackAnchor(\"qr\")")
        assertThat(source).contains("regenerateQrFocus")
        assertThat(source).contains("clearCacheFocus")
        // 顶/底锚点必须真正滚到 0/max，禁止永远居中导致到不了两端。
        assertThat(source).contains("SETTINGS_TOP_EDGE_ANCHOR_KEYS")
        assertThat(source).contains("SETTINGS_BOTTOM_EDGE_ANCHOR_KEYS")
        assertThat(source).doesNotContain("scrollAnchorToCenter")
    }

    /**
     * 顶区（含登录按钮）目标必须为 0，底区必须为 max。
     */
    @Test
    fun focus_scroll_target_reaches_true_top_and_bottom() {
        assertThat(
            computeSettingsFocusScrollTarget(
                anchorKey = "server",
                anchorTop = 80,
                anchorHeight = 52,
                viewport = 600,
                currentScroll = 200,
                maxScroll = 1200,
            ),
        ).isEqualTo(0)
        // 登录按钮获焦时也要回顶，保证滚动内容顶部全部可见。
        assertThat(
            computeSettingsFocusScrollTarget(
                anchorKey = "saveServer",
                anchorTop = 320,
                anchorHeight = 50,
                viewport = 600,
                currentScroll = 180,
                maxScroll = 1200,
            ),
        ).isEqualTo(0)
        assertThat(SETTINGS_TOP_EDGE_ANCHOR_KEYS).containsAtLeast(
            "server",
            "account",
            "password",
            "saveServer",
        )
        assertThat(
            computeSettingsFocusScrollTarget(
                anchorKey = "clearCache",
                anchorTop = 1500,
                anchorHeight = 52,
                viewport = 600,
                currentScroll = 200,
                maxScroll = 1200,
            ),
        ).isEqualTo(1200)
    }

    /**
     * 中部锚点仅在裁切时移动，已完全可见时保持当前位置。
     */
    @Test
    fun middle_anchor_only_scrolls_when_clipped() {
        // 项已在视口中：不滚动。
        assertThat(
            computeSettingsFocusScrollTarget(
                anchorKey = "theme",
                anchorTop = 400,
                anchorHeight = 52,
                viewport = 600,
                currentScroll = 300,
                maxScroll = 1200,
            ),
        ).isEqualTo(300)
        // 项在视口下方被裁：向下滚到露出底边。
        val scrolledDown = computeSettingsFocusScrollTarget(
            anchorKey = "theme",
            anchorTop = 900,
            anchorHeight = 52,
            viewport = 600,
            currentScroll = 200,
            maxScroll = 1200,
        )
        assertThat(scrolledDown).isGreaterThan(200)
        assertThat(scrolledDown).isAtMost(1200)
    }

    /**
     * 壳层不得用 appearance key 整树重建，否则设置页确认后滚回顶部。
     */
    @Test
    fun app_shell_must_not_key_nav_graph_on_appearance_change() {
        // 单测工作目录为 feature-tv-settings 模块根。
        val appSource = File(
            "../app-tv/src/main/java/org/moontechlab/selene/tv/app/TvApp.kt",
        ).readText()
        assertThat(appSource).doesNotContain("key(appearance.themeKey")
        assertThat(appSource).contains("禁止 key() 整树重建")
    }

    /**
     * 设置页必须把顶部导航下探入口绑定到服务器地址真实输入行。
     */
    @Test
    fun route_source_attaches_content_focus_requester_to_server_url() {
        val source = readRouteSource()

        assertThat(source).contains("contentFocusRequester: FocusRequester? = null")
        assertThat(source).contains("val settingsEntryFocusRequester = contentFocusRequester ?: serverUrlFocus")
        assertThat(source).contains("focusRequester = settingsEntryFocusRequester")
    }

    /**
     * 二维码区域必须支持真实扫码数据与重新生成。
     */
    @Test
    fun route_source_renders_real_qr_section() {
        val source = readRouteSource()
        assertThat(source).contains("TvQrCodeSection")
        assertThat(source).contains("qrData = state.qrData")
        assertThat(source).contains("onRegenerateQr")
        assertThat(source).contains("regenerateFocusRequester = regenerateQrFocus")
    }

    /**
     * 读取设置页 Route 源码。
     */
    private fun readRouteSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/feature/settings/TvSettingsRoute.kt")
            .readText()
    }
}
