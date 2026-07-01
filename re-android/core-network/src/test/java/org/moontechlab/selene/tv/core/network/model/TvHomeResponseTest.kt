package org.moontechlab.selene.tv.core.network.model

import com.google.common.truth.Truth.assertThat
import com.google.gson.Gson
import org.junit.Test

/**
 * 校验 TV 首页响应模型兼容 Flutter TV 卡片字段。
 */
class TvHomeResponseTest {
    /**
     * 首页视频卡片应优先读取 Flutter TV 使用的 cover 字段。
     */
    @Test
    fun videoCardResponse_prefersFlutterCoverField() {
        val response = Gson().fromJson(
            """
            {
              "id": "movie-1",
              "source": "source-a",
              "title": "电影 A",
              "source_name": "线路 A",
              "year": "2026",
              "cover": "cover-a.jpg",
              "poster": "poster-a.jpg",
              "posterUrl": "poster-url-a.jpg"
            }
            """.trimIndent(),
            TvVideoCardResponse::class.java,
        )

        assertThat(response.id).isEqualTo("movie-1")
        assertThat(response.source).isEqualTo("source-a")
        assertThat(response.sourceName).isEqualTo("线路 A")
        assertThat(response.year).isEqualTo("2026")
        assertThat(response.resolvedPosterUrl()).isEqualTo("cover-a.jpg")
    }

    /**
     * 缺少 cover 时应回退到搜索接口常用的 poster 字段。
     */
    @Test
    fun videoCardResponse_fallsBackToPosterField() {
        val response = Gson().fromJson(
            """
            {
              "id": "movie-2",
              "title": "电影 B",
              "poster": "poster-b.jpg",
              "posterUrl": "poster-url-b.jpg"
            }
            """.trimIndent(),
            TvVideoCardResponse::class.java,
        )

        assertThat(response.resolvedPosterUrl()).isEqualTo("poster-b.jpg")
    }

    /**
     * 缺少 Flutter 字段时应兼容原生 TV 初版 posterUrl 字段。
     */
    @Test
    fun videoCardResponse_fallsBackToPosterUrlField() {
        val response = Gson().fromJson(
            """
            {
              "id": "movie-3",
              "title": "电影 C",
              "posterUrl": "poster-url-c.jpg"
            }
            """.trimIndent(),
            TvVideoCardResponse::class.java,
        )

        assertThat(response.resolvedPosterUrl()).isEqualTo("poster-url-c.jpg")
    }
}
