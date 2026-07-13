package org.moontechlab.selene.tv.core.network

import org.moontechlab.selene.tv.core.network.model.BangumiCalendarDayResponse
import retrofit2.http.GET

/**
 * Bangumi 公开 API。
 *
 * 用于新番放送日历，对齐 Flutter BangumiService 主接口。
 */
interface SeleneBangumiApi {
    /**
     * 获取整周新番放送日历。
     *
     * @return 按星期分组的放送列表。
     */
    @GET("calendar")
    suspend fun getCalendar(): List<BangumiCalendarDayResponse>
}
