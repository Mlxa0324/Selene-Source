package org.moontechlab.selene.tv.app.navigation

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 TV 顶级路由的公开契约。
 */
class TvDestinationTest {
    /**
     * 确认顶部导航暴露的路由顺序与设计一致。
     */
    @Test
    fun topLevelDestinations_expose_expected_routes() {
        val routes = TvDestination.topLevelDestinations.map { it.route }

        assertThat(routes).containsExactly(
            "home",
            "search",
            "history",
            "favorites",
            "settings",
            "live",
        ).inOrder()
    }

    /**
     * 确认全屏播放器路由不会泄露到顶部导航。
     */
    @Test
    fun fullscreen_player_route_is_hidden_from_top_level_tabs() {
        assertThat(TvDestination.Player.route).isEqualTo("player/{videoId}")
        assertThat(TvDestination.topLevelDestinations).doesNotContain(TvDestination.Player)
    }

    /**
     * 确认首页与直播属于左侧主菜单。
     */
    @Test
    fun primary_menu_destinations_expose_home_and_live() {
        val routes = TvDestination.primaryMenuDestinations.map { it.route }

        assertThat(routes).containsExactly(
            "home",
            "live",
        ).inOrder()
    }

    /**
     * 确认搜索与工具页属于右上角快捷入口。
     */
    @Test
    fun quick_access_destinations_expose_expected_routes() {
        val routes = TvDestination.quickAccessDestinations.map { it.route }

        assertThat(routes).containsExactly(
            "search",
            "history",
            "favorites",
            "settings",
        ).inOrder()
    }
}
