package org.moontechlab.selene.tv.app.navigation

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.moontechlab.selene.tv.feature.home.TvHomeSectionMoreTarget

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
            "library/movie",
            "library/tv",
            "library/anime",
            "library/show",
            "live",
            "search",
            "history",
            "favorites",
            "settings",
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
     * 确认播放器提供统一参数常量和路由构造方法。
     */
    @Test
    fun player_route_builder_encodes_video_id() {
        assertThat(TvDestination.Player.videoIdArg).isEqualTo("videoId")
        assertThat(
            TvDestination.Player.createRoute("anime/id?ep=01 中文"),
        ).isEqualTo("player/anime%2Fid%3Fep%3D01%20%E4%B8%AD%E6%96%87")
    }

    /**
     * 确认首页与直播属于左侧主菜单。
     */
    @Test
    fun primary_menu_destinations_expose_home_and_live() {
        val routes = TvDestination.primaryMenuDestinations.map { it.route }

        assertThat(routes).containsExactly(
            "home",
            "library/movie",
            "library/tv",
            "library/anime",
            "library/show",
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

    /**
     * 确认快捷入口暴露图标符号，供顶部按钮渲染图标加文字。
     */
    @Test
    fun quick_access_destinations_expose_icon_glyphs() {
        val iconGlyphs = TvDestination.quickAccessDestinations.map { it.iconGlyph }

        assertThat(iconGlyphs).containsExactly(
            "⌕",
            "↺",
            "★",
            "⚙",
        ).inOrder()
    }

    /**
     * 确认首页查看更多目标能映射到既有顶层路由，避免额外引入中转页面。
     */
    @Test
    fun home_section_more_targets_map_to_existing_top_level_destinations() {
        assertThat(TvHomeSectionMoreTarget.History.toDestination().route)
            .isEqualTo(TvDestination.History.route)
        assertThat(TvHomeSectionMoreTarget.Movie.toDestination().route)
            .isEqualTo(TvDestination.Movie.route)
        assertThat(TvHomeSectionMoreTarget.Tv.toDestination().route)
            .isEqualTo(TvDestination.Tv.route)
        assertThat(TvHomeSectionMoreTarget.Anime.toDestination().route)
            .isEqualTo(TvDestination.Anime.route)
        assertThat(TvHomeSectionMoreTarget.Show.toDestination().route)
            .isEqualTo(TvDestination.Show.route)
        assertThat(TvHomeSectionMoreTarget.Favorites.toDestination().route)
            .isEqualTo(TvDestination.Favorites.route)
    }

    /**
     * 确认导航展示文案对齐 Flutter TV 顶部入口。
     */
    @Test
    fun topLevelDestinations_expose_tv_labels() {
        val labels = TvDestination.topLevelDestinations.map { it.label }

        assertThat(labels).containsExactly(
            "首页",
            "电影",
            "剧集",
            "动漫",
            "综艺",
            "直播",
            "搜索",
            "播放历史",
            "收藏夹",
            "设置",
        ).inOrder()
    }
}
