package org.moontechlab.selene.tv.app.navigation

import java.net.URLEncoder
import java.nio.charset.StandardCharsets

/**
 * 描述 TV 壳当前阶段支持的全部路由。
 *
 * @property route Compose Navigation 使用的路由字符串。
 */
sealed class TvDestination(
    val route: String,
) {
    /**
     * 首页路由。
     */
    data object Home : TvDestination("home")

    /**
     * 搜索页路由。
     */
    data object Search : TvDestination("search")

    /**
     * 播放历史页路由。
     */
    data object History : TvDestination("history")

    /**
     * 收藏夹页路由。
     */
    data object Favorites : TvDestination("favorites")

    /**
     * 设置页路由。
     */
    data object Settings : TvDestination("settings")

    /**
     * 直播占位页路由。
     */
    data object Live : TvDestination("live")

    /**
     * 全屏播放器路由。
     */
    data object Player : TvDestination("player/{videoId}") {
        /**
         * 播放器路由参数名。
         */
        const val videoIdArg = "videoId"

        /**
         * 根据视频 ID 构造可安全传递的播放器路由。
         *
         * @param videoId 原始视频 ID。
         * @return 经过编码后的播放器路由。
         */
        fun createRoute(videoId: String): String {
            // 对动态参数做 URL 编码，避免斜杠和空格污染路由层级。
            val encodedVideoId = URLEncoder.encode(
                videoId,
                StandardCharsets.UTF_8.toString(),
            ).replace("+", "%20")
            return "player/$encodedVideoId"
        }
    }

    companion object {
        /**
         * 左侧主菜单仅承载首页与直播入口。
         */
        val primaryMenuDestinations = listOf(
            Home,
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
            Live,
            Search,
            History,
            Favorites,
            Settings,
        )
    }
}
