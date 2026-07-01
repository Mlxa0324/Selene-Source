package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.network.SeleneDanmakuApi
import org.moontechlab.selene.tv.core.network.model.TvDanmakuCommentListResponse
import org.moontechlab.selene.tv.core.network.model.TvDanmakuCommentResponse
import org.moontechlab.selene.tv.core.network.model.TvDanmakuSearchAnimeResponse
import org.moontechlab.selene.tv.core.network.model.TvDanmakuSearchEpisodeResponse
import org.moontechlab.selene.tv.core.network.model.TvDanmakuSearchResponse

/**
 * 校验 TV 弹幕仓库的数据映射。
 */
class TvDanmakuRepositoryTest {
    /**
     * 搜索弹幕剧集时必须把接口 DTO 转成业务层稳定模型。
     */
    @Test
    fun searchEpisodes_maps_network_response_to_domain_model() = runTest {
        val api = RecordingDanmakuApi(
            response = TvDanmakuSearchResponse(
                success = true,
                errorMessage = "",
                animes = listOf(
                    TvDanmakuSearchAnimeResponse(
                        animeId = 101,
                        animeTitle = "测试番剧",
                        type = "tv",
                        typeDescription = "TV",
                        year = 2024,
                        episodes = listOf(
                            TvDanmakuSearchEpisodeResponse(
                                episodeId = 9001,
                                episodeTitle = "第 1 集",
                            ),
                        ),
                    ),
                ),
            ),
        )
        val repository = TvDanmakuRepository(api = api)

        val result = repository.searchEpisodes("  测试番剧  ")

        assertThat(api.lastAnimeQuery).isEqualTo("测试番剧")
        assertThat(result?.success).isTrue()
        assertThat(result?.animes?.first()?.animeTitle).isEqualTo("测试番剧")
        assertThat(result?.animes?.first()?.episodes?.first()?.episodeId).isEqualTo(9001)
    }

    /**
     * 空搜索词不应请求弹幕服务。
     */
    @Test
    fun searchEpisodes_ignores_blank_query() = runTest {
        val api = RecordingDanmakuApi(response = TvDanmakuSearchResponse())
        val repository = TvDanmakuRepository(api = api)

        val result = repository.searchEpisodes("   ")

        assertThat(result).isNull()
        assertThat(api.lastAnimeQuery).isNull()
    }

    /**
     * 加载弹幕评论时必须使用 Flutter 同款 json 格式并按播放时间排序。
     */
    @Test
    fun loadDanmakuByEpisodeId_requests_json_comments_and_sorts_by_time() = runTest {
        val api = RecordingDanmakuApi(
            response = TvDanmakuSearchResponse(),
            commentsResponse = TvDanmakuCommentListResponse(
                count = 2,
                comments = listOf(
                    TvDanmakuCommentResponse(
                        cid = 11,
                        p = "12.5,1,16777215,0",
                        m = "晚到的弹幕",
                        t = 1710000000,
                    ),
                    TvDanmakuCommentResponse(
                        cid = 12,
                        p = "3.25,5,65280,0",
                        m = "先出现的顶部弹幕",
                        t = 1710000001,
                    ),
                ),
            ),
        )
        val repository = TvDanmakuRepository(api = api)

        val result = repository.loadDanmakuByEpisodeId(9001)

        assertThat(api.lastCommentEpisodeId).isEqualTo(9001)
        assertThat(api.lastCommentFormat).isEqualTo("json")
        assertThat(result.episodeId).isEqualTo(9001)
        assertThat(result.comments.map { comment -> comment.text })
            .containsExactly("先出现的顶部弹幕", "晚到的弹幕")
            .inOrder()
        assertThat(result.comments.first().timeSeconds).isEqualTo(3.25)
        assertThat(result.comments.first().type).isEqualTo(5)
        assertThat(result.comments.first().color).isEqualTo(65_280)
    }
}

/**
 * 测试用弹幕接口。
 *
 * @property response 固定返回的弹幕搜索响应。
 */
private class RecordingDanmakuApi(
    private val response: TvDanmakuSearchResponse,
    private val commentsResponse: TvDanmakuCommentListResponse = TvDanmakuCommentListResponse(),
) : SeleneDanmakuApi {
    /** 最近一次搜索词。 */
    var lastAnimeQuery: String? = null

    /** 最近一次评论请求剧集 ID。 */
    var lastCommentEpisodeId: Int? = null

    /** 最近一次评论请求格式。 */
    var lastCommentFormat: String? = null

    /**
     * 记录搜索词并返回固定响应。
     *
     * @param anime 动画搜索词。
     * @return 固定响应。
     */
    override suspend fun searchEpisodes(anime: String): TvDanmakuSearchResponse {
        lastAnimeQuery = anime
        return response
    }

    /**
     * 记录评论请求并返回固定响应。
     *
     * @param episodeId 弹幕剧集 ID。
     * @param format 评论返回格式。
     * @return 固定评论响应。
     */
    override suspend fun getComments(
        episodeId: Int,
        format: String,
    ): TvDanmakuCommentListResponse {
        lastCommentEpisodeId = episodeId
        lastCommentFormat = format
        return commentsResponse
    }
}
