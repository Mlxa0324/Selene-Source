package org.moontechlab.selene.tv.app.navigation

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
    data object Player : TvDestination("player/{videoId}")

    companion object {
        /**
         * 顶层导航仅暴露主页面签，不包含全屏播放器。
         */
        val topLevelDestinations = listOf(
            Home,
            Search,
            History,
            Favorites,
            Settings,
            Live,
        )
    }
}
