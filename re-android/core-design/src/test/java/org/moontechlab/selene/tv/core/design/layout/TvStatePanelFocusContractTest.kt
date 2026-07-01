package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 状态面板的遥控器焦点契约。
 */
class TvStatePanelFocusContractTest {
    /**
     * 状态面板必须能接收顶部导航向下传入的内容焦点请求器。
     */
    @Test
    fun state_panel_accepts_content_focus_requester() {
        val source = readStatePanelSource()

        assertThat(source).contains("import androidx.compose.ui.focus.FocusRequester")
        assertThat(source).contains("contentFocusRequester: FocusRequester? = null")
    }

    /**
     * 没有操作按钮的状态面板也必须提供焦点目标，避免加载和空态把遥控器困在顶部导航。
     */
    @Test
    fun state_panel_declares_fallback_focus_target_when_action_is_missing() {
        val source = readStatePanelSource()

        assertThat(source).contains("import androidx.compose.foundation.focusable")
        assertThat(source).contains("Modifier.focusRequester(contentFocusRequester).focusable()")
    }

    /**
     * 有操作按钮时焦点请求器必须挂到按钮上，确保错误态下方向键可直接落到重试操作。
     */
    @Test
    fun state_panel_attaches_content_focus_to_action_button() {
        val source = readStatePanelSource()

        assertThat(source).contains("import androidx.compose.ui.focus.focusRequester")
        assertThat(source).contains("val actionFocusModifier")
        assertThat(source).contains("Button(")
        assertThat(source).contains("modifier = actionFocusModifier")
    }

    /**
     * 空状态快捷组件必须把内容入口继续传给通用状态面板。
     */
    @Test
    fun empty_state_panel_delegates_content_focus_requester() {
        val source = readEmptyStatePanelSource()

        assertThat(source).contains("import androidx.compose.ui.focus.FocusRequester")
        assertThat(source).contains("contentFocusRequester: FocusRequester? = null")
        assertThat(source).contains("contentFocusRequester = contentFocusRequester")
    }

    /**
     * 读取状态面板源码。
     *
     * @return 当前 TvStatePanel 源码文本。
     */
    private fun readStatePanelSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvStatePanel.kt")
            .readText()
    }

    /**
     * 读取空状态面板源码。
     *
     * @return 当前 TvEmptyStatePanel 源码文本。
     */
    private fun readEmptyStatePanelSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/core/design/layout/TvEmptyStatePanel.kt")
            .readText()
    }
}
