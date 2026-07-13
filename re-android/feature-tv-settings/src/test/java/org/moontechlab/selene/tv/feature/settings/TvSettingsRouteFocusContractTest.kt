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
        assertThat(source).contains("focusAndScroll")
        assertThat(source).contains("scrollAnchorToCenter")
        assertThat(source).contains("positionInRoot()")
        assertThat(source).contains("regenerateModifier = Modifier.trackAnchor(\"qr\")")
        assertThat(source).contains("regenerateQrFocus")
        assertThat(source).contains("clearCacheFocus")
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
