package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.network.SeleneBangumiApi
import org.moontechlab.selene.tv.core.network.model.BangumiCalendarDayResponse
import org.moontechlab.selene.tv.core.network.model.BangumiImagesResponse
import org.moontechlab.selene.tv.core.network.model.BangumiItemResponse
import org.moontechlab.selene.tv.core.network.model.BangumiRatingResponse
import org.moontechlab.selene.tv.core.network.model.BangumiWeekdayResponse

/**
 * 校验 Bangumi 日历仓库映射与按星期筛选。
 */
class BangumiRepositoryTest {
    /**
     * 应按 weekday 返回对应日的新番，并映射成 bangumi 来源卡片。
     */
    @Test
    fun loadCalendarByWeekday_maps_items_for_target_day() = runTest {
        val repository = BangumiRepository(
            api = object : SeleneBangumiApi {
                override suspend fun getCalendar(): List<BangumiCalendarDayResponse> {
                    return listOf(
                        day(1, listOf(item(101, "周一番", "Monday Show"))),
                        day(3, listOf(item(303, "周三番", "Wednesday Show"))),
                    )
                }
            },
        )

        val cards = repository.loadCalendarByWeekday(3)

        assertThat(cards).hasSize(1)
        assertThat(cards.first().id).isEqualTo("303")
        assertThat(cards.first().title).isEqualTo("周三番")
        assertThat(cards.first().source).isEqualTo("bangumi")
        assertThat(cards.first().sourceName).isEqualTo("Bangumi")
        assertThat(cards.first().posterUrl).isEqualTo("https://lain.bgm.tv/pic/cover/l/303.jpg")
        assertThat(cards.first().doubanRate).isEqualTo("8.5")
    }

    private fun day(id: Int, items: List<BangumiItemResponse>): BangumiCalendarDayResponse {
        return BangumiCalendarDayResponse(
            weekday = BangumiWeekdayResponse(id = id, cn = "星期$id"),
            items = items,
        )
    }

    private fun item(id: Int, nameCn: String, name: String): BangumiItemResponse {
        return BangumiItemResponse(
            id = id,
            name = name,
            nameCn = nameCn,
            airDate = "2026-07-13",
            airWeekday = 3,
            rating = BangumiRatingResponse(score = 8.5),
            images = BangumiImagesResponse(large = "https://lain.bgm.tv/pic/cover/l/$id.jpg"),
        )
    }
}
