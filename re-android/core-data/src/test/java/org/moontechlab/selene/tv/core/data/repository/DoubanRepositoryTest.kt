package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.network.DoubanSubjectHtmlSource
import org.moontechlab.selene.tv.core.network.SeleneDoubanApi
import org.moontechlab.selene.tv.core.network.model.DoubanCategoryResponse

/**
 * 校验豆瓣仓库详情推荐数据边界。
 */
class DoubanRepositoryTest {
    /**
     * HTML 数据源返回推荐页面时，仓库应传入指定豆瓣 ID 并返回解析后的卡片。
     */
    @Test
    fun loadDetailRecommends_uses_memory_cache_on_second_call() = runTest {
        var fetchCount = 0
        val repository = DoubanRepository(
            api = UnusedDoubanApi,
            htmlSource = DoubanSubjectHtmlSource {
                fetchCount += 1
                RECOMMENDATION_HTML
            },
        )

        val first = repository.loadDetailRecommends("1292052")
        val second = repository.loadDetailRecommends("1292052")

        assertThat(first).isNotEmpty()
        assertThat(second).isEqualTo(first)
        assertThat(fetchCount).isEqualTo(1)
    }

    /**
     * 相关推荐 TTL 默认 1 天，与 Flutter 豆瓣成功结果缓存时长一致。
     */
    @Test
    fun recommend_cache_ttl_is_one_day() {
        assertThat(DoubanRepository.RECOMMEND_CACHE_TTL_MS).isEqualTo(86_400_000L)
    }

    /**
     * 未过期时命中缓存；超过 TTL 后应重新抓 HTML。
     */
    @Test
    fun loadDetailRecommends_refetches_after_ttl_expires() = runTest {
        var fetchCount = 0
        var now = 1_000_000L
        val repository = DoubanRepository(
            api = UnusedDoubanApi,
            htmlSource = DoubanSubjectHtmlSource {
                fetchCount += 1
                RECOMMENDATION_HTML
            },
            recommendTtlMs = DoubanRepository.RECOMMEND_CACHE_TTL_MS,
            nowMs = { now },
        )

        val first = repository.loadDetailRecommends("1292052")
        // TTL 内：仍命中。
        now += DoubanRepository.RECOMMEND_CACHE_TTL_MS - 1
        val withinTtl = repository.loadDetailRecommends("1292052")
        // 刚过 TTL：重新请求。
        now += 2
        val afterTtl = repository.loadDetailRecommends("1292052")

        assertThat(first).isNotEmpty()
        assertThat(withinTtl).isEqualTo(first)
        assertThat(afterTtl).isEqualTo(first)
        assertThat(fetchCount).isEqualTo(2)
    }

    @Test
    fun loadDetailRecommends_fetches_html_and_returns_parsed_cards() = runTest {
        val source = DoubanSubjectHtmlSource { doubanId ->
            assertThat(doubanId).isEqualTo("1292052")
            RECOMMENDATION_HTML
        }
        val repository = DoubanRepository(
            api = UnusedDoubanApi,
            htmlSource = source,
        )

        val cards = repository.loadDetailRecommends("1292052")

        assertThat(cards.map { card -> card.id })
            .containsExactly("1111111", "2222222")
            .inOrder()
        assertThat(cards.map { card -> card.posterUrl })
            .containsExactly("https://img.test/a.jpg", "https://img.test/b.jpg")
            .inOrder()
    }

    /**
     * 未注入 HTML 数据源时，仓库应返回空列表且不访问网络。
     */
    @Test
    fun loadDetailRecommends_returns_empty_when_html_source_is_absent() = runTest {
        val repository = DoubanRepository(
            api = UnusedDoubanApi,
            htmlSource = null,
        )

        assertThat(repository.loadDetailRecommends("1292052")).isEmpty()
    }

    /**
     * HTML 抓取失败时，仓库应把原始异常传播给推荐生命周期处理。
     */
    @Test
    fun loadDetailRecommends_propagates_fetch_failure() = runTest {
        val expected = IllegalStateException("推荐请求失败")
        val repository = DoubanRepository(
            api = UnusedDoubanApi,
            htmlSource = DoubanSubjectHtmlSource { throw expected },
        )

        val actual = try {
            repository.loadDetailRecommends("1292052")
            null
        } catch (throwable: Throwable) {
            throwable
        }

        assertThat(actual).isSameInstanceAs(expected)
    }

    private companion object {
        /** 覆盖协议相对条目链接、协议相对海报和缺少评分的推荐 HTML。 */
        val RECOMMENDATION_HTML = """
            <div id="recommendations">
              <div class="recommendations-bd">
                <dl>
                  <dt><a href="//movie.douban.com/subject/1111111/"><img alt="推荐甲" src="//img.test/a.jpg"></a></dt>
                  <dd><span class="subject-rate">9.1</span></dd>
                </dl>
                <dl>
                  <dt><a href="/subject/2222222/"><img src="https://img.test/b.jpg" alt="推荐乙"></a></dt>
                </dl>
              </div>
            </div>
        """.trimIndent()
    }
}

/**
 * 详情推荐测试中不会调用的豆瓣分类 API 替身。
 */
private object UnusedDoubanApi : SeleneDoubanApi {
    /**
     * 禁止详情推荐测试误调用分类接口。
     *
     * @param kind 影视类型。
     * @param start 分页偏移。
     * @param limit 每页数量。
     * @param category 分类名称。
     * @param type 子类型。
     * @return 本方法不会返回。
     */
    override suspend fun getCategoryData(
        kind: String,
        start: Int,
        limit: Int,
        category: String,
        type: String,
    ): DoubanCategoryResponse {
        error("详情推荐测试不应调用豆瓣分类接口")
    }

    /**
     * 禁止详情推荐测试误调用高级推荐接口。
     *
     * @param kind 影视类型。
     * @param refresh 刷新标记。
     * @param start 分页偏移。
     * @param count 每页数量。
     * @param selectedCategories 已选分类。
     * @param uncollect 是否排除收藏。
     * @param scoreRange 评分范围。
     * @param tags 标签条件。
     * @param sort 排序方式。
     * @return 本方法不会返回。
     */
    override suspend fun getRecommends(
        kind: String,
        refresh: Int,
        start: Int,
        count: Int,
        selectedCategories: String,
        uncollect: Boolean,
        scoreRange: String,
        tags: String,
        sort: String,
    ): DoubanCategoryResponse {
        error("详情推荐测试不应调用豆瓣高级推荐接口")
    }
}
