package org.moontechlab.selene.core.model

data class CatalogVideo(
    val id: String,
    val title: String,
    val sourceKey: String,
    val sourceName: String,
    val year: String,
    val typeName: String,
    val description: String,
    val posterUrl: String = "",
    val episodes: List<VideoEpisode>,
)

object DemoVideoCatalog {
    val videos: List<CatalogVideo> = listOf(
        CatalogVideo(
            id = "video-santi-ff",
            title = "三体",
            sourceKey = "ffm3u8",
            sourceName = "非凡影视",
            year = "2023",
            typeName = "科幻",
            description = "纳米材料学家卷入文明存亡危机，科学边界被不断推向极限。",
            episodes = listOf(
                VideoEpisode(index = 0, title = "第1集", playUrl = "https://media.example.com/santi-01.m3u8"),
                VideoEpisode(index = 1, title = "第2集", playUrl = "https://media.example.com/santi-02.m3u8"),
                VideoEpisode(index = 2, title = "第3集", playUrl = "https://media.example.com/santi-03.m3u8"),
                VideoEpisode(index = 3, title = "第4集", playUrl = "https://media.example.com/santi-04.m3u8"),
            ),
        ),
        CatalogVideo(
            id = "video-santi-bf",
            title = "三体",
            sourceKey = "bfzy",
            sourceName = "暴风资源",
            year = "2023",
            typeName = "科幻",
            description = "同名多源条目，用于模拟搜索聚合和换源场景。",
            episodes = listOf(
                VideoEpisode(index = 0, title = "第1集", playUrl = "https://media.example.com/santi-bf-01.m3u8"),
                VideoEpisode(index = 1, title = "第2集", playUrl = "https://media.example.com/santi-bf-02.m3u8"),
            ),
        ),
        CatalogVideo(
            id = "video-fanren-dm",
            title = "凡人修仙传",
            sourceKey = "dm84",
            sourceName = "动漫港",
            year = "2024",
            typeName = "动画",
            description = "凡人少年步入修仙世界，逐步成长为能够自保的修士。",
            episodes = listOf(
                VideoEpisode(index = 0, title = "第1集", playUrl = "https://media.example.com/fanren-01.m3u8"),
                VideoEpisode(index = 1, title = "第2集", playUrl = "https://media.example.com/fanren-02.m3u8"),
                VideoEpisode(index = 2, title = "第3集", playUrl = "https://media.example.com/fanren-03.m3u8"),
            ),
        ),
        CatalogVideo(
            id = "video-wandering-cn",
            title = "流浪地球 2",
            sourceKey = "heimuer",
            sourceName = "黑木耳资源",
            year = "2023",
            typeName = "科幻",
            description = "太阳危机逼近，人类尝试在灾变前完成地球发动机计划。",
            episodes = listOf(
                VideoEpisode(index = 0, title = "正片", playUrl = "https://media.example.com/wandering-earth-2.m3u8"),
            ),
        ),
    )

    fun search(keyword: String): List<CatalogVideo> {
        val cleanKeyword = keyword.trim()
        if (cleanKeyword.isEmpty()) return emptyList()
        return videos.filter { video ->
            video.title.contains(cleanKeyword, ignoreCase = true) ||
                video.sourceName.contains(cleanKeyword, ignoreCase = true) ||
                video.typeName.contains(cleanKeyword, ignoreCase = true) ||
                video.year.contains(cleanKeyword, ignoreCase = true)
        }
    }

    fun findById(id: String): CatalogVideo? = videos.firstOrNull { it.id == id }
}

object DemoServerVideoCatalog {
    val videos: List<CatalogVideo> = listOf(
        CatalogVideo(
            id = "video-santi-server",
            title = "三体",
            sourceKey = "selene-api",
            sourceName = "Selene 聚合",
            year = "2023",
            typeName = "科幻",
            description = "服务器聚合详情：保留统一标题，但返回服务器侧整理过的来源和选集。",
            episodes = listOf(
                VideoEpisode(index = 0, title = "第1集", playUrl = "https://server.example.com/santi-01.m3u8"),
                VideoEpisode(index = 1, title = "第2集", playUrl = "https://server.example.com/santi-02.m3u8"),
            ),
        ),
        CatalogVideo(
            id = "video-fanren-server",
            title = "凡人修仙传",
            sourceKey = "selene-api",
            sourceName = "Selene 聚合",
            year = "2024",
            typeName = "动画",
            description = "服务器聚合详情：用于模拟服务器模式下的统一源详情。",
            episodes = listOf(
                VideoEpisode(index = 0, title = "第1集", playUrl = "https://server.example.com/fanren-01.m3u8"),
                VideoEpisode(index = 1, title = "第2集", playUrl = "https://server.example.com/fanren-02.m3u8"),
            ),
        ),
    )

    fun search(keyword: String): List<CatalogVideo> {
        val cleanKeyword = keyword.trim()
        if (cleanKeyword.isEmpty()) return emptyList()
        return videos.filter { video ->
            video.title.contains(cleanKeyword, ignoreCase = true) ||
                video.sourceName.contains(cleanKeyword, ignoreCase = true) ||
                video.typeName.contains(cleanKeyword, ignoreCase = true) ||
                video.year.contains(cleanKeyword, ignoreCase = true)
        }
    }

    fun findById(id: String): CatalogVideo? = videos.firstOrNull { it.id == id }
}
