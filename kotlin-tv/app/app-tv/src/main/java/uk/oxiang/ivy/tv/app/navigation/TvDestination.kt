package uk.oxiang.ivy.tv.app.navigation

import java.net.URLEncoder
import java.nio.charset.StandardCharsets

/**
 * 描述 TV 壳当前阶段支持的全部路由。
 *
 * @property route Compose Navigation 使用的路由字符串。
 * @property label TV UI 展示文案。
 * @property iconGlyph 顶部快捷入口展示的轻量图标符号。
 */
sealed class TvDestination(
    val route: String,
    val label: String,
    val iconGlyph: String? = null,
) {
    /** 首页路由。 */
    data object Home : TvDestination("home", "首页")

    /** 电影分类页路由。 */
    data object Movie : TvDestination("library/movie", "电影")

    /** 剧集分类页路由。 */
    data object Tv : TvDestination("library/tv", "剧集")

    /** 动漫分类页路由。 */
    data object Anime : TvDestination("library/anime", "动漫")

    /** 综艺分类页路由。 */
    data object Show : TvDestination("library/show", "综艺")

    /** 搜索页路由。 */
    data object Search : TvDestination("search", "搜索", "⌕")

    /** 播放历史页路由。 */
    data object History : TvDestination("history", "播放历史", "↺")

    /** 收藏夹页路由。 */
    data object Favorites : TvDestination("favorites", "收藏夹", "♥")

    /** 设置页路由。 */
    data object Settings : TvDestination("settings", "设置", "⚙")

    /** 直播页路由。 */
    data object Live : TvDestination("live", "直播")

    /** 影视详情路由。 */
    data object Detail : TvDestination(detailRoutePattern, "详情") {
        /** 详情路由参数名。 */
        const val videoIdArg: String = DETAIL_VIDEO_ID_ARG

        /**
         * 根据视频 ID 构造可安全传递的详情路由。
         *
         * @param videoId 原始视频 ID。
         * @return 经过编码后的详情路由。
         */
        fun createRoute(videoId: String): String {
            return "$detailPathPrefix/${encodeRouteArg(videoId)}"
        }
    }

    /** 全屏播放器路由。 */
    data object Player : TvDestination(playerRoutePattern, "播放器") {
        /** 播放请求路由参数名。 */
        const val requestIdArg: String = PLAYER_REQUEST_ID_ARG

        /**
         * 根据播放请求 ID 构造可安全传递的播放器路由。
         *
         * @param requestId 播放请求暂存 ID。
         * @return 经过编码后的播放器路由。
         */
        fun createRoute(requestId: String): String {
            return "$playerPathPrefix/${encodeRouteArg(requestId)}"
        }
    }

    companion object {
        /** 详情路由参数名单一源。 */
        private const val DETAIL_VIDEO_ID_ARG = "videoId"

        /** 播放器请求参数名单一源。 */
        private const val PLAYER_REQUEST_ID_ARG = "requestId"

        /** 详情路径前缀单一源。 */
        private const val detailPathPrefix = "detail"

        /** 播放器路径前缀单一源。 */
        private const val playerPathPrefix = "player"

        /** 详情路由模板单一源。 */
        private const val detailRoutePattern = "$detailPathPrefix/{$DETAIL_VIDEO_ID_ARG}"

        /** 播放器路由模板单一源。 */
        private const val playerRoutePattern = "$playerPathPrefix/{$PLAYER_REQUEST_ID_ARG}"

        /**
         * 编码动态路由参数。
         *
         * @param rawArg 原始参数。
         * @return 可放入路径片段的编码值。
         */
        private fun encodeRouteArg(rawArg: String): String {
            return URLEncoder.encode(rawArg, StandardCharsets.UTF_8.toString()).replace("+", "%20")
        }

        /** 左侧主菜单承载首页、内容分类与直播入口。 */
        val primaryMenuDestinations = listOf(Home, Movie, Tv, Anime, Show, Live)

        /** 右上角快捷入口承载搜索与工具页入口。 */
        val quickAccessDestinations = listOf(Search, History, Favorites, Settings)

        /** 顶层导航仅暴露主页面签，不包含全屏播放器和详情页。 */
        val topLevelDestinations = listOf(Home, Movie, Tv, Anime, Show, Live, Search, History, Favorites, Settings)
    }
}
