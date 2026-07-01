package org.moontechlab.selene.tv.feature.player

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import org.junit.Rule
import org.junit.Test

/**
 * 校验 TV 全屏播放器壳的菜单入口。
 */
class TvPlayerRouteTest {
    /** Compose 测试规则。 */
    @get:Rule
    val composeRule = createComposeRule()

    /**
     * 打开其它菜单后应展示内核切换入口。
     */
    @Test
    fun player_route_opens_other_menu_and_shows_engine_switch_entry() {
        val viewModel = TvPlayerViewModel().apply {
            // 底部菜单默认隐藏，测试菜单项时先进入播放列表菜单态。
            openMenu(PLAYER_MENU_PLAYLIST)
        }
        composeRule.setContent {
            TvPlayerRoute(viewModel = viewModel)
        }

        composeRule.onNodeWithTag("tv-player-menu-other").performClick()
        composeRule.onNodeWithText("内核切换").assertExists()
    }
}
