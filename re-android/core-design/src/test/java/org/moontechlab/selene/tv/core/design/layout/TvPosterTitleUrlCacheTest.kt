package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import org.junit.After
import org.junit.Test

/**
 * 校验按片名精确匹配的封面 URL 缓存契约。
 */
class TvPosterTitleUrlCacheTest {
    @After
    fun tearDown() {
        TvPosterTitleUrlCache.clearForTest()
    }

    /**
     * 成功写入后应按片名精确命中。
     */
    @Test
    fun put_and_get_uses_exact_title_match() {
        TvPosterTitleUrlCache.putSuccess("痴迷", "https://cdn.test/a.jpg")

        assertThat(TvPosterTitleUrlCache.get("痴迷")).isEqualTo("https://cdn.test/a.jpg")
        assertThat(TvPosterTitleUrlCache.get(" 痴迷 ")).isEqualTo("https://cdn.test/a.jpg")
        // 不折叠空白、不忽略大小写：非精准匹配不应命中。
        assertThat(TvPosterTitleUrlCache.get("痴 迷")).isNull()
        assertThat(TvPosterTitleUrlCache.get("CHI MI")).isNull()
    }

    /**
     * 主 URL 为空时应直接用同名缓存。
     */
    @Test
    fun resolvePrimaryUrl_falls_back_when_poster_blank() {
        TvPosterTitleUrlCache.putSuccess("痴迷", "https://cdn.test/cached.jpg")

        assertThat(
            TvPosterTitleUrlCache.resolvePrimaryUrl(title = "痴迷", posterUrl = ""),
        ).isEqualTo("https://cdn.test/cached.jpg")
        assertThat(
            TvPosterTitleUrlCache.resolvePrimaryUrl(
                title = "痴迷",
                posterUrl = "https://cdn.test/primary.jpg",
            ),
        ).isEqualTo("https://cdn.test/primary.jpg")
    }

    /**
     * 失败回退不能再返回同一个失败 URL。
     */
    @Test
    fun resolveFallbackUrl_skips_failed_url() {
        TvPosterTitleUrlCache.putSuccess("痴迷", "https://cdn.test/good.jpg")

        assertThat(
            TvPosterTitleUrlCache.resolveFallbackUrl(
                title = "痴迷",
                failedUrl = "https://cdn.test/broken.jpg",
            ),
        ).isEqualTo("https://cdn.test/good.jpg")
        assertThat(
            TvPosterTitleUrlCache.resolveFallbackUrl(
                title = "痴迷",
                failedUrl = "https://cdn.test/good.jpg",
            ),
        ).isNull()
    }
}
