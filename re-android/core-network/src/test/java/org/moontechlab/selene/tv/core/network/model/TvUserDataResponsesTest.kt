package org.moontechlab.selene.tv.core.network.model

import com.google.common.truth.Truth.assertThat
import com.google.gson.Gson
import org.junit.Test

/**
 * 校验 TV 用户数据响应模型的时间戳兼容性。
 */
class TvUserDataResponsesTest {
    /**
     * 13 位毫秒时间戳应能被正常解析。
     */
    @Test
    fun playRecordResponse_parses_millisecond_save_time() {
        val response = Gson().fromJson(
            """
            {
              "title": "继续观看",
              "save_time": 1772967985455
            }
            """.trimIndent(),
            TvPlayRecordResponse::class.java,
        )

        assertThat(response.saveTime).isEqualTo(1772967985455L)
    }

    /**
     * 收藏夹 13 位毫秒时间戳也应能被正常解析。
     */
    @Test
    fun favoriteResponse_parses_millisecond_save_time() {
        val response = Gson().fromJson(
            """
            {
              "title": "收藏",
              "save_time": 1772967985455
            }
            """.trimIndent(),
            TvFavoriteResponse::class.java,
        )

        assertThat(response.saveTime).isEqualTo(1772967985455L)
    }
}
