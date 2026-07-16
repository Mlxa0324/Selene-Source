package org.moontechlab.selene.tv.feature.settings

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * TV 设置页焦点契约测试。
 */
class TvSettingsRouteFocusContractTest {
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
        assertThat(source).contains("scrollAnchorToCenter")
        assertThat(source).contains("positionInRoot()")
        assertThat(source).contains("regenerateModifier = Modifier.trackAnchor(\"qr\")")
        assertThat(source).contains("regenerateQrFocus")
        assertThat(source).contains("clearCacheFocus")
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
