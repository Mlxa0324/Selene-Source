package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.SeleneBangumiApi
import org.moontechlab.selene.tv.core.network.model.BangumiCalendarDayResponse
import org.moontechlab.selene.tv.core.network.model.BangumiImagesResponse
import org.moontechlab.selene.tv.core.network.model.BangumiItemResponse
import java.util.Calendar

/**
 * Bangumi 新番放送仓库。
 *
 * 对齐 Flutter `BangumiService.getCalendarByWeekday`：
 * 1. 请求 `https://api.bgm.tv/calendar` 整周数据；
 * 2. 按 weekday(1=周一...7=周日) 取当日条目；
 * 3. 映射为 TV 海报卡片，source 固定为 bangumi。
 *
 * @property api Bangumi 接口。
 */
class BangumiRepository(
    private val api: SeleneBangumiApi,
) {
    /** 内存缓存整周原始日历，减少重复请求。 */
    @Volatile
    private var cachedCalendar: List<BangumiCalendarDayResponse>? = null

    /**
     * 获取今天新番放送。
     *
     * @return 今日放送卡片列表。
     */
    suspend fun loadTodayCalendar(): List<TvVideoCard> {
        return loadCalendarByWeekday(currentWeekday())
    }

    /**
     * 获取指定星期的新番放送。
     *
     * @param weekday 1=周一 ... 7=周日。
     * @return 指定日放送卡片列表。
     */
    suspend fun loadCalendarByWeekday(weekday: Int): List<TvVideoCard> {
        val safeWeekday = weekday.coerceIn(1, 7)
        val calendar = loadCalendar()
        val day = calendar.firstOrNull { day -> day.weekday?.id == safeWeekday }
            ?: return emptyList()
        return day.items.orEmpty().mapNotNull { item -> item.toVideoCard() }
    }

    /**
     * 拉取并缓存整周日历。
     *
     * @return 日历天列表。
     */
    private suspend fun loadCalendar(): List<BangumiCalendarDayResponse> {
        cachedCalendar?.let { return it }
        val remote = api.getCalendar()
        cachedCalendar = remote
        return remote
    }

    /**
     * 清除日历缓存。
     */
    fun clearCache() {
        cachedCalendar = null
    }

    private companion object {
        /**
         * 当前设备星期，对齐 DateTime.now().weekday。
         *
         * @return 1=周一 ... 7=周日。
         */
        fun currentWeekday(): Int {
            val calendar = Calendar.getInstance()
            // Calendar.SUNDAY=1 ... SATURDAY=7，映射为 ISO 周一=1。
            return when (val day = calendar.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> 1
                Calendar.TUESDAY -> 2
                Calendar.WEDNESDAY -> 3
                Calendar.THURSDAY -> 4
                Calendar.FRIDAY -> 5
                Calendar.SATURDAY -> 6
                Calendar.SUNDAY -> 7
                else -> day
            }
        }
    }
}

/**
 * Bangumi 条目转 TV 卡片。
 *
 * @return 有效卡片；缺 ID/标题时返回 null。
 */
private fun BangumiItemResponse.toVideoCard(): TvVideoCard? {
    val videoId = id?.takeIf { value -> value > 0 }?.toString().orEmpty()
    if (videoId.isBlank()) {
        return null
    }
    val title = nameCn.orEmpty().trim().ifBlank { name.orEmpty().trim() }
    if (title.isBlank()) {
        return null
    }
    val year = airDate.orEmpty().trim().take(4)
    val rate = rating?.score
        ?.takeIf { score -> score > 0.0 }
        ?.let { score -> "%.1f".format(score) }
        .orEmpty()
    return TvVideoCard(
        id = videoId,
        source = "bangumi",
        title = title,
        sourceName = "Bangumi",
        year = year,
        posterUrl = images.bestImageUrl(),
        totalEpisodes = 1,
        episodeIndex = 1,
        searchTitle = title,
        origin = "bangumi",
        doubanRate = rate,
    )
}

/**
 * 选择可用封面地址。
 *
 * @return 优先 large → common → medium → small → grid。
 */
private fun BangumiImagesResponse?.bestImageUrl(): String {
    if (this == null) {
        return ""
    }
    return large.orEmpty().ifBlank {
        common.orEmpty().ifBlank {
            medium.orEmpty().ifBlank {
                small.orEmpty().ifBlank {
                    grid.orEmpty()
                }
            }
        }
    }
}
