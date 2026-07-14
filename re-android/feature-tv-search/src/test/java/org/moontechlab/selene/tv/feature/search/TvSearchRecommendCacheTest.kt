package org.moontechlab.selene.tv.feature.search

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * 校验搜索页推荐缓存对齐 Flutter TvSearchRecommendService。
 */
class TvSearchRecommendCacheTest {
    /**
     * 无详情沉淀时，应走兜底 loader。
     */
    @Test
    fun loadSearchRecommends_uses_fallback_when_cache_empty() = runTest {
        val cache = TvSearchRecommendCache()
        val fallback = listOf(card("f1", "兜底1"), card("f2", "兜底2"))

        val result = cache.loadSearchRecommends { fallback }

        assertThat(result.map { it.id }).containsExactly("f1", "f2").inOrder()
    }

    /**
     * 有详情相关推荐时，优先返回缓存，不调用兜底。
     */
    @Test
    fun loadSearchRecommends_prefers_detail_cache_over_fallback() = runTest {
        val cache = TvSearchRecommendCache()
        cache.recordDetailRecommends(
            source = "src-a",
            videoId = "v1",
            title = "详情A",
            recommends = listOf(card("r1", "相关1"), card("r2", "相关2")),
        )
        var fallbackCalls = 0

        val result = cache.loadSearchRecommends {
            fallbackCalls += 1
            listOf(card("f1", "兜底"))
        }

        assertThat(fallbackCalls).isEqualTo(0)
        assertThat(result.map { it.id }).containsExactly("r1", "r2").inOrder()
    }

    /**
     * 最多保留两组；新组在前；跨组同名去重保留先出现的。
     */
    @Test
    fun recordDetailRecommends_keeps_two_groups_newest_first_and_dedupes() = runTest {
        val cache = TvSearchRecommendCache()
        cache.recordDetailRecommends(
            source = "s1",
            videoId = "old",
            title = "旧详情",
            recommends = listOf(card("o1", "旧片"), card("dup", "重复片")),
        )
        cache.recordDetailRecommends(
            source = "s2",
            videoId = "mid",
            title = "中详情",
            recommends = listOf(card("m1", "中片"), card("dup2", "重复片")),
        )
        cache.recordDetailRecommends(
            source = "s3",
            videoId = "new",
            title = "新详情",
            recommends = listOf(card("n1", "新片")),
        )

        val result = cache.loadSearchRecommends { emptyList() }

        // 最多两组：新 + 中；旧组被淘汰。「重复片」只保留中组那次。
        assertThat(result.map { it.title }).containsExactly("新片", "中片", "重复片").inOrder()
        assertThat(result.map { it.id }).doesNotContain("o1")
    }

    /**
     * 同一详情再次打开应刷新到顶部，不重复占两组。
     */
    @Test
    fun recordDetailRecommends_replaces_same_detail_group() = runTest {
        val cache = TvSearchRecommendCache()
        cache.recordDetailRecommends(
            source = "s1",
            videoId = "v1",
            title = "同片",
            recommends = listOf(card("old-r", "旧推荐")),
        )
        cache.recordDetailRecommends(
            source = "s2",
            videoId = "v2",
            title = "另一部",
            recommends = listOf(card("other", "另一推荐")),
        )
        cache.recordDetailRecommends(
            source = "s1",
            videoId = "v1",
            title = "同片",
            recommends = listOf(card("new-r", "新推荐")),
        )

        val result = cache.peekCachedRecommends()

        assertThat(result.map { it.id }).containsExactly("new-r", "other").inOrder()
    }

    private fun card(id: String, title: String): TvVideoCard {
        return TvVideoCard(
            id = id,
            source = "douban",
            title = title,
            posterUrl = "https://img.test/$id.jpg",
        )
    }
}
