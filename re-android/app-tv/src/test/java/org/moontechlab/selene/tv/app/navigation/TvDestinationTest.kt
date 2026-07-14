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
        assertThat(TvDestination.Player.route).isEqualTo("player/{requestId}")
        assertThat(TvDestination.topLevelDestinations).doesNotContain(TvDestination.Player)
    }

    /**
     * 弹幕手动匹配路由必须隐藏在顶层导航外，并安全携带默认搜索词。
     */
    @Test
    fun danmaku_match_route_builder_encodes_initial_query() {
        assertThat(TvDestination.DanmakuMatch.route).isEqualTo("danmaku-match/{query}")
        assertThat(TvDestination.topLevelDestinations).doesNotContain(TvDestination.DanmakuMatch)
        assertThat(TvDestination.DanmakuMatch.queryArg).isEqualTo("query")
        assertThat(TvDestination.DanmakuMatch.createRoute("测试 影片/第2集"))
            .isEqualTo("danmaku-match/%E6%B5%8B%E8%AF%95%20%E5%BD%B1%E7%89%87%2F%E7%AC%AC2%E9%9B%86")
    }

    /**
     * 确认播放器提供播放请求 ID 参数和路由构造方法。
     */
    @Test
    fun player_route_builder_encodes_request_id() {
        assertThat(TvDestination.Player.requestIdArg).isEqualTo("requestId")
        assertThat(
            TvDestination.Player.createRoute("playback/id?seq=01 中文"),
        ).isEqualTo("player/playback%2Fid%3Fseq%3D01%20%E4%B8%AD%E6%96%87")
    }

    /**
     * 确认详情路由携带 source 和 id，支持 `/api/detail` 精准取源。
     */
    @Test
    fun detail_route_builder_encodes_source_and_video_id() {
        val key = TvDestination.Detail.createVideoKey(
            source = "source/a",
            videoId = "video?id=01 中文",
        )

        assertThat(key).isEqualTo("source/a::video?id=01 中文")
        assertThat(TvDestination.Detail.parseSource(key)).isEqualTo("source/a")
        assertThat(TvDestination.Detail.parseVideoId(key)).isEqualTo("video?id=01 中文")
        assertThat(TvDestination.Detail.createRoute(key))
            .isEqualTo("detail/source%2Fa%3A%3Avideo%3Fid%3D01%20%E4%B8%AD%E6%96%87")
    }

    /**
     * 左侧主菜单：首页、分类、播放历史、收藏夹；直播暂时隐藏。
     */
    @Test
    fun primary_menu_destinations_expose_home_and_categories() {
        val routes = TvDestination.primaryMenuDestinations.map { it.route }

        assertThat(routes).containsExactly(
            "home",
            "library/movie",
            "library/tv",
            "library/anime",
            "library/show",
            "history",
            "favorites",
        ).inOrder()
        assertThat(routes).doesNotContain("live")
        assertThat(TvDestination.topLevelDestinations.map { it.route }).doesNotContain("live")
        // 主菜单文字 tab 不带图标。
        assertThat(TvDestination.History.iconGlyph).isNull()
        assertThat(TvDestination.Favorites.iconGlyph).isNull()
    }

    /**
     * 右上角快捷入口仅保留搜索与设置。
     */
    @Test
    fun quick_access_destinations_expose_expected_routes() {
        val routes = TvDestination.quickAccessDestinations.map { it.route }

        assertThat(routes).containsExactly(
            "search",
            "settings",
        ).inOrder()
    }

    /**
     * 右上角快捷入口暴露图标符号（搜索、设置）。
     */
    @Test
    fun quick_access_destinations_expose_icon_glyphs() {
        val iconGlyphs = TvDestination.quickAccessDestinations.map { it.iconGlyph }

        assertThat(iconGlyphs).containsExactly(
            "⌕",
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

        // topLevel 顺序：主菜单项在前，快捷入口在后。
        assertThat(labels).containsExactly(
            "首页",
            "电影",
            "剧集",
            "动漫",
            "综艺",
            "搜索",
            "播放历史",
            "收藏夹",
            "设置",
        ).inOrder()
    }

    /**
     * 相关推荐携带中文标题时，解析后必须是可读原文，不能残留 URL 编码。
     */
    @Test
    fun detail_route_title_is_not_double_encoded() {
        val key = TvDestination.Detail.createVideoKeyWithTitle(
            source = "douban",
            videoId = "123456",
            title = "阿松的日常",
        )
        val route = TvDestination.Detail.createRoute(key)

        assertThat(key).isEqualTo("douban::123456::阿松的日常")
        assertThat(TvDestination.Detail.parseTitle(key)).isEqualTo("阿松的日常")
        // createRoute 只编码整段 path，不应让 parseTitle 再看到 %E9...
        assertThat(route).contains("%E9%98%BF")
        assertThat(TvDestination.Detail.parseTitle("douban::123456::%E9%98%BF%E6%9D%BE%E7%9A%84%E6%97%A5%E5%B8%B8"))
            .isEqualTo("阿松的日常")
    }
}
