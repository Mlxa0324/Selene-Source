package org.moontechlab.selene.tv.app.navigation

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
    data object Search : TvDestination("search", "搜索", "⌕")

    /**
     * 播放历史页路由。
     */
    data object History : TvDestination("history", "播放历史", "↺")

    /**
     * 收藏夹页路由。
     */
    data object Favorites : TvDestination("favorites", "收藏夹", "♥")

    /**
     * 设置页路由。
     */
    data object Settings : TvDestination("settings", "设置", "⚙")

    /**
     * 直播页路由。
     */
    data object Live : TvDestination("live", "直播")

    /**
     * 弹幕手动匹配路由。
     */
    data object DanmakuMatch : TvDestination(danmakuMatchRoutePattern, "手动匹配弹幕") {
        /**
         * 默认搜索词参数名。
         */
        const val queryArg: String = DANMAKU_MATCH_QUERY_ARG

        /**
         * 根据默认搜索词构造弹幕匹配路由。
         *
         * @param query 默认搜索词，通常为当前片名。
         * @return 经过编码后的弹幕匹配路由。
         */
        fun createRoute(query: String): String {
            val routeQuery = query.ifBlank { danmakuMatchEmptyQuerySentinel }
            return "$danmakuMatchPathPrefix/${encodeRouteArg(routeQuery)}"
        }

        /**
         * 解析弹幕匹配默认搜索词。
         *
         * @param queryArg 路由参数中的搜索词。
         * @return 还原后的搜索词。
         */
        fun parseQuery(queryArg: String): String {
            return if (queryArg == danmakuMatchEmptyQuerySentinel) {
                ""
            } else {
                queryArg
            }
        }
    }

    /**
     * 全屏播放器路由。
     */
    data object Player : TvDestination(playerRoutePattern, "播放器") {
        /**
         * 播放请求路由参数名。
         */
        const val requestIdArg: String = PLAYER_REQUEST_ID_ARG

        /**
         * 根据播放请求 ID 构造可安全传递的播放器路由。
         *
         * @param requestId 播放请求暂存 ID。
         * @return 经过编码后的播放器路由。
         */
        fun createRoute(requestId: String): String {
            // 对动态参数做 URL 编码，避免斜杠和空格污染路由层级。
            val encodedRequestId = encodeRouteArg(requestId)
            return "$playerPathPrefix/$encodedRequestId"
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

        /** 详情路由中 source、id 和 title 的分隔符。 */
        private const val videoKeySeparator = "::"

        /**
         * 根据视频 ID 构造可安全传递的详情路由。
         *
         * @param videoId 原始视频 ID 或 `source::id` 或 `source::id::encodedTitle` 详情 key。
         * @return 经过编码后的详情路由。
         */
        fun createRoute(videoId: String): String {
            val encodedVideoId = encodeRouteArg(videoId)
            return "$detailPathPrefix/$encodedVideoId"
        }

        /**
         * 创建详情页精准取源 key。
         *
         * @param source 播放来源标识。
         * @param videoId 视频 ID。
         * @return 可放入详情路由的 `source::id`。
         */
        fun createVideoKey(
            source: String,
            videoId: String,
        ): String {
            return if (source.isBlank()) {
                videoId
            } else {
                "$source$videoKeySeparator$videoId"
            }
        }

        /**
         * 创建携带标题的详情 key（用于未知来源卡片通过标题搜索兜底）。
         *
         * @param source 播放来源标识。
         * @param videoId 视频 ID。
         * @param title 视频标题。
         * @return 可放入详情路由的 `source::id::encodedTitle`。
         */
        fun createVideoKeyWithTitle(
            source: String,
            videoId: String,
            title: String,
        ): String {
            val key = createVideoKey(source, videoId)
            return if (title.isBlank()) {
                key
            } else {
                "$key$videoKeySeparator${encodeRouteArg(title)}"
            }
        }

        /**
         * 从详情 key 解析播放来源。
         *
         * @param videoKey 详情路由参数。
         * @return 播放来源；旧路由无来源时返回空字符串。
         */
        fun parseSource(videoKey: String): String {
            return videoKey.substringBefore(videoKeySeparator, missingDelimiterValue = "")
        }

        /**
         * 从详情 key 解析视频 ID。
         *
         * @param videoKey 详情路由参数。
         * @return 视频 ID。
         */
        fun parseVideoId(videoKey: String): String {
            val withoutSource = videoKey.substringAfter(videoKeySeparator, missingDelimiterValue = videoKey)
            return withoutSource.substringBefore(videoKeySeparator, missingDelimiterValue = withoutSource)
        }

        /**
         * 从详情 key 解析视频标题。
         *
         * @param videoKey 详情路由参数 `source::id::encodedTitle`。
         * @return 视频标题；key 中没有标题时返回空字符串。
         */
        fun parseTitle(videoKey: String): String {
            val parts = videoKey.split(videoKeySeparator, limit = 3)
            return if (parts.size >= 3) parts[2].trim() else ""
        }
    }

    companion object {
        /**
         * 播放器请求参数名单一源。
         */
        private const val PLAYER_REQUEST_ID_ARG = "requestId"

        /**
         * 详情路由参数名单一源。
         */
        private const val DETAIL_VIDEO_ID_ARG = "videoId"

        /**
         * 弹幕匹配默认搜索词参数名单一源。
         */
        private const val DANMAKU_MATCH_QUERY_ARG = "query"

        /**
         * 播放器路径前缀单一源。
         */
        private const val playerPathPrefix = "player"

        /**
         * 详情路径前缀单一源。
         */
        private const val detailPathPrefix = "detail"

        /**
         * 弹幕匹配路径前缀单一源。
         */
        private const val danmakuMatchPathPrefix = "danmaku-match"

        /**
         * 空搜索词路径哨兵值，避免 Compose path 参数无法匹配空片段。
         */
        private const val danmakuMatchEmptyQuerySentinel = "_"

        /**
         * 播放器路由模板单一源。
         */
        private const val playerRoutePattern = "$playerPathPrefix/{$PLAYER_REQUEST_ID_ARG}"

        /**
         * 详情路由模板单一源。
         */
        private const val detailRoutePattern = "$detailPathPrefix/{$DETAIL_VIDEO_ID_ARG}"

        /**
         * 弹幕匹配路由模板单一源。
         */
        private const val danmakuMatchRoutePattern = "$danmakuMatchPathPrefix/{$DANMAKU_MATCH_QUERY_ARG}"

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
