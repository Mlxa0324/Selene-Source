package org.moontechlab.selene.app.navigation

import java.net.URLEncoder
import java.nio.charset.StandardCharsets

sealed class SeleneDestination(
    val route: String,
    val label: String,
) {
    data object Startup : SeleneDestination(route = "startup", label = "启动")

    data object Auth : SeleneDestination(route = "auth", label = "登录")

    data object Favorites : SeleneDestination(route = "favorites", label = "收藏")

    data object History : SeleneDestination(route = "history", label = "历史")

    data object Home : SeleneDestination(route = "home", label = "首页")

    data object Search : SeleneDestination(route = "search", label = "搜索")

    data object Live : SeleneDestination(route = "live", label = "直播")

    data object Resource : SeleneDestination(route = "resource", label = "资源站")

    data object Download : SeleneDestination(route = "download", label = "下载")

    data object Profile : SeleneDestination(route = "profile", label = "我的")

    data object Benchmark : SeleneDestination(route = "benchmark", label = "Benchmark")

    data object Detail : SeleneDestination(route = "detail/{videoId}?sourceKey={sourceKey}", label = "详情") {
        fun createRoute(
            videoId: String,
            sourceKey: String = "",
        ): String = buildString {
            append("detail/")
            append(videoId.encodeRouteSegment())
            if (sourceKey.isNotBlank()) {
                append("?sourceKey=")
                append(sourceKey.encodeRouteSegment())
            }
        }
    }

    data object Player : SeleneDestination(
        route = "player/{videoId}/{title}/{sourceKey}/{sourceName}/{episodeTitle}/{playUrl}",
        label = "播放器",
    ) {
        fun createRoute(
            videoId: String,
            title: String,
            sourceKey: String = "",
            sourceName: String = "",
            episodeTitle: String,
            playUrl: String,
        ): String = buildString {
            append("player/")
            append(videoId.encodeRouteSegment())
            append("/")
            append(title.encodeRouteSegment())
            append("/")
            append(sourceKey.encodeRouteSegment())
            append("/")
            append(sourceName.encodeRouteSegment())
            append("/")
            append(episodeTitle.encodeRouteSegment())
            append("/")
            append(playUrl.encodeRouteSegment())
        }
    }

    companion object {
        val topLevelDestinations: List<SeleneDestination>
            get() = listOf(
                Home,
                Search,
                Live,
                Resource,
                Download,
                Profile,
                Benchmark,
            )

        val defaultBottomNavDestinations: List<SeleneDestination>
            get() = listOf(
                Home,
                Search,
                Live,
                Resource,
                Download,
                Profile,
            )
    }
}

private fun String.encodeRouteSegment(): String = URLEncoder
    .encode(this, StandardCharsets.UTF_8.toString())
    .replace("+", "%20")
