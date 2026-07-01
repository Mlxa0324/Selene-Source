package org.moontechlab.selene.tv.feature.search

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验 TV 搜索页遥控器焦点契约。
 */
class TvSearchRouteFocusContractTest {
    /**
     * 右侧面板所有状态都必须承接键盘右移入口，避免按右方向键后丢焦。
     */
    @Test
    fun right_panel_states_attach_entry_focus_requester() {
        val source = readRouteSource()

        assertThat(source).contains("private fun SearchPromptPanel(")
        assertThat(source).contains("entryFocusRequester: FocusRequester")
        assertThat(source).contains("onReturnToLeftPanel: () -> Unit")
        assertThat(source).contains("private fun SearchResultPanel(")
        assertThat(source).contains("firstItemFocusRequester = entryFocusRequester")
        assertThat(source).contains("TvSearchStatePanel(")
        assertThat(source).contains("focusRequester = entryFocusRequester")
    }

    /**
     * 搜索结果和提示面板必须能按左方向键回到最近键盘按键。
     */
    @Test
    fun right_panel_entry_can_return_to_keyboard_with_left_key() {
        val source = readRouteSource()

        assertThat(source).contains("onLeft = onReturnToLeftPanel")
        assertThat(source).contains("onReturnToLeftPanel = onReturnToLeftPanel")
    }

    /**
     * 读取搜索 Route 源码。
     *
     * @return Route 源码文本。
     */
    private fun readRouteSource(): String {
        return File("src/main/java/org/moontechlab/selene/tv/feature/search/TvSearchRoute.kt")
            .readText()
    }
}
