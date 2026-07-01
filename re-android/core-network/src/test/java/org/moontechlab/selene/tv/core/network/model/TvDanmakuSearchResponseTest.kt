package org.moontechlab.selene.tv.core.network.model

import com.google.common.truth.Truth.assertThat
import com.google.gson.Gson
import org.junit.Test

/**
 * 校验弹幕搜索接口响应模型。
 */
class TvDanmakuSearchResponseTest {
    /**
     * 弹幕搜索响应必须兼容 Flutter 使用的 animes 与 episodes 结构。
     */
    @Test
    fun danmakuSearchResponse_parses_animes_and_episodes() {
        val response = Gson().fromJson(
            """
            {
              "errorCode": 0,
              "success": true,
              "errorMessage": "",
              "animes": [
                {
                  "animeId": 101,
                  "animeTitle": "测试番剧",
                  "type": "tv",
                  "typeDescription": "TV",
                  "year": 2024,
                  "episodes": [
                    {
                      "episodeId": 9001,
                      "episodeTitle": "第 1 集"
                    }
                  ]
                }
              ]
            }
            """.trimIndent(),
            TvDanmakuSearchResponse::class.java,
        )

        assertThat(response.success).isTrue()
        assertThat(response.errorCode).isEqualTo(0)
        assertThat(response.animes).hasSize(1)
        assertThat(response.animes?.first()?.year).isEqualTo(2024)
        assertThat(response.animes?.first()?.episodes?.first()?.episodeId).isEqualTo(9001)
    }

    /**
     * 弹幕评论响应必须兼容 Flutter 使用的 count、comments 和 p 字段结构。
     */
    @Test
    fun danmakuCommentListResponse_parses_comments_and_p_fields() {
        val response = Gson().fromJson(
            """
            {
              "count": 2,
              "comments": [
                {
                  "cid": 11,
                  "p": "12.5,1,16777215,0",
                  "m": "第一条弹幕",
                  "t": 1710000000
                },
                {
                  "cid": 12,
                  "p": "3.25,5,65280,0",
                  "m": "顶部弹幕",
                  "t": 1710000001
                }
              ]
            }
            """.trimIndent(),
            TvDanmakuCommentListResponse::class.java,
        )

        assertThat(response.count).isEqualTo(2)
        assertThat(response.comments).hasSize(2)
        assertThat(response.comments?.first()?.timeSeconds).isEqualTo(12.5)
        assertThat(response.comments?.first()?.type).isEqualTo(1)
        assertThat(response.comments?.first()?.color).isEqualTo(16_777_215)
        assertThat(response.comments?.last()?.type).isEqualTo(5)
        assertThat(response.comments?.last()?.color).isEqualTo(65_280)
    }
}
