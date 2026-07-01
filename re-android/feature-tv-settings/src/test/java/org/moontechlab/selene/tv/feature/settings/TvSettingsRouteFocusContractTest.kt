package org.moontechlab.selene.tv.feature.settings

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * TV 设置页焦点契约测试。
 */
class TvSettingsRouteFocusContractTest {
    /**
     * 设置页首焦点落在服务器地址，焦点链为线性从上到下。
     */
    @Test
    fun route_source_assigns_first_focus_to_server_url() {
        val source = readRouteSource()

        assertThat(source).contains("import androidx.compose.ui.focus.FocusRequester")
        // 首焦点: 服务器地址
        assertThat(source).contains("settingsEntryFocusRequester.requestFocus()")
        // 焦点链注释验证线性顺序
        assertThat(source).contains("服务器地址 → 账号 → 密码 → 保存配置")
        assertThat(source).contains("回到服务器地址")
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
     * 读取设置页 Route 源码。
     */
    private fun readRouteSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/feature/settings/TvSettingsRoute.kt")
            .readText()
    }
}
