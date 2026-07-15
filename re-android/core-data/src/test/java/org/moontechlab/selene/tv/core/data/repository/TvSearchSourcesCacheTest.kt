package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoSource

/**
 * 详情补源搜索缓存契约：TTL 2h、命中续约，对齐 Flutter 手机端。
 */
class TvSearchSourcesCacheTest {
    /**
     * TTL 必须与 Flutter `UserDataService._sourcesDataCacheTtl`（7200 秒）一致。
     */
    @Test
    fun default_ttl_matches_flutter_mobile_two_hours() {
        assertThat(TvSearchSourcesCache.DEFAULT_TTL_MS).isEqualTo(7_200_000L)
    }

    /**
     * 未过期应命中，并在再次 get 时续约。
     */
    @Test
    fun get_returns_cached_sources_and_renews_ttl() {
        var now = 1_000_000L
        val cache = TvSearchSourcesCache(
            ttlMs = 7_200_000L,
            nowMs = { now },
        )
        val sources = listOf(sampleSource("a"))
        cache.put(" 火影忍者 ", sources)

        assertThat(cache.get("火影忍者")).isEqualTo(sources)

        // 推进到接近过期：若未续约会在 1_000_000+7_200_000 失效；
        // 上面 get 已续约到 now=1_000_000，再把 now 设为 1_000_000+7_199_000 仍应命中。
        now = 1_000_000L + 7_199_000L
        assertThat(cache.get("火影忍者")).isEqualTo(sources)
    }

    /**
     * 超过 2 小时应视为过期并删除。
     */
    @Test
    fun get_returns_null_after_ttl_expires() {
        var now = 0L
        val cache = TvSearchSourcesCache(
            ttlMs = 7_200_000L,
            nowMs = { now },
        )
        cache.put("q", listOf(sampleSource("a")))
        now = 7_200_000L
        assertThat(cache.get("q")).isNull()
        assertThat(cache.size()).isEqualTo(0)
    }

    /**
     * 空结果不写入，避免缓存“无源”挡住后续真实搜索。
     */
    @Test
    fun put_ignores_empty_sources() {
        val cache = TvSearchSourcesCache()
        cache.put("q", emptyList())
        assertThat(cache.get("q")).isNull()
        assertThat(cache.size()).isEqualTo(0)
    }

    private fun sampleSource(id: String): TvVideoSource {
        return TvVideoSource(
            id = "source-$id::video-$id",
            source = "source-$id",
            videoId = "video-$id",
            name = "线路 $id",
            episodes = listOf(
                TvEpisode(id = "ep-1", title = "第01集", url = "https://cdn.test/$id.m3u8"),
            ),
        )
    }
}
