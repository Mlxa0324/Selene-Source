package org.moontechlab.selene.tv.app.navigation

import java.net.URLEncoder
import java.nio.charset.StandardCharsets

/**
 * 描述 TV 壳当前阶段支持的全部路由。
 *
 * @property route Compose Navigation 使用的路由字符串。
 * @property label TV UI 展示文案。
 */
sealed class TvDestination(
    val route: String,
    val label: String,
) {
    /**
     * 首页路由。
     */
    data object Home : TvDestination("home", "首页")

    /**
     * 电影分类页路由。
     */
    data object Movie : TvDestination("library/movie", "电影")

    /**
     * 剧集分类页路由。
     */
    data object Tv : TvDestination("library/tv", "剧集")

    /**
     * 动漫分类页路由。
     */
    data object Anime : TvDestination("library/anime", "动漫")

    /**
     * 综艺分类页路由。
     */
    data object Show : TvDestination("library/show", "综艺")

    /**
     * 搜索页路由。
     */
    data object Search : TvDestination("search", "搜索")

    /**
     * 播放历史页路由。
     */
    data object History : TvDestination("history", "播放历史")

    /**
     * 收藏夹页路由。
     */
    data object Favorites : TvDestination("favorites", "收藏夹")

    /**
     * 设置页路由。
     */
    data object Settings : TvDestination("settings", "设置")

    /**
     * 直播占位页路由。
     */
    data object Live : TvDestination("live", "直播")

    /**
     * 全屏播放器路由。
     */
    data object Player : TvDestination(playerRoutePattern, "播放器") {
        /**
         * 播放器路由参数名。
         */
        const val videoIdArg: String = PLAYER_VIDEO_ID_ARG

        /**
         * 根据视频 ID 构造可安全传递的播放器路由。
         *
         * @param videoId 原始视频 ID。
         * @return 经过编码后的播放器路由。
         */
        fun createRoute(videoId: String): String {
            // 对动态参数做 URL 编码，避免斜杠和空格污染路由层级。
            val encodedVideoId = encodeRouteArg(videoId)
            return "$playerPathPrefix/$encodedVideoId"
        }
    }

    /**
     * 影视详情路由。
     */
    data object Detail : TvDestination(detailRoutePattern, "详情") {
        /**
         * 详情路由参数名。
         */
        const val videoIdArg: String = DETAIL_VIDEO_ID_ARG

        /**
         * 根据视频 ID 构造可安全传递的详情路由。
         *
         * @param videoId 原始视频 ID。
         * @return 经过编码后的详情路由。
         */
        fun createRoute(videoId: String): String {
            val encodedVideoId = encodeRouteArg(videoId)
            return "$detailPathPrefix/$encodedVideoId"
        }
    }

    companion object {
        /**
         * 播放器路由参数名单一源。
         */
        private const val PLAYER_VIDEO_ID_ARG = "videoId"

        /**
         * 详情路由参数名单一源。
         */
        private const val DETAIL_VIDEO_ID_ARG = "videoId"

        /**
         * 播放器路径前缀单一源。
         */
        private const val playerPathPrefix = "player"

        /**
         * 详情路径前缀单一源。
         */
        private const val detailPathPrefix = "detail"

        /**
         * 播放器路由模板单一源。
         */
        private const val playerRoutePattern = "$playerPathPrefix/{$PLAYER_VIDEO_ID_ARG}"

        /**
         * 详情路由模板单一源。
         */
        private const val detailRoutePattern = "$detailPathPrefix/{$DETAIL_VIDEO_ID_ARG}"

        /**
         * 编码动态路由参数。
         *
         * @param rawArg 原始参数。
         * @return 可放入路径片段的编码值。
         */
        private fun encodeRouteArg(rawArg: String): String {
            return URLEncoder.encode(
                rawArg,
                StandardCharsets.UTF_8.toString(),
            ).replace("+", "%20")
        }

        /**
         * 左侧主菜单承载首页、内容分类与直播入口。
         */
        val primaryMenuDestinations = listOf(
            Home,
            Movie,
            Tv,
            Anime,
            Show,
            Live,
        )

        /**
         * 右上角快捷入口承载搜索与工具页入口。
         */
        val quickAccessDestinations = listOf(
            Search,
            History,
            Favorites,
            Settings,
        )

        /**
         * 顶层导航仅暴露主页面签，不包含全屏播放器。
         */
        val topLevelDestinations = listOf(
            Home,
            Movie,
            Tv,
            Anime,
            Show,
            Live,
            Search,
            History,
            Favorites,
            Settings,
        )
    }
}
