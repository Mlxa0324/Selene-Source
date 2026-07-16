package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验豆瓣图片代理 URL 改写契约。
 */
class TvDoubanImageUrlTest {
    @Test
    fun resolve_official_cdn_rewrites_douban_host() {
        val original = "https://img9.doubanio.com/view/photo/s_ratio_poster/public/p1.jpg"
        assertThat(resolveDoubanImageUrl(original, "official_cdn"))
            .isEqualTo("https://img3.doubanio.com/view/photo/s_ratio_poster/public/p1.jpg")
    }

    @Test
    fun resolve_tencent_cdn_rewrites_douban_host() {
        val original = "https://img1.doubanio.com/view/photo/s_ratio_poster/public/p1.jpg"
        assertThat(resolveDoubanImageUrl(original, "tencent_cdn"))
            .isEqualTo("https://img.doubanio.cmliussss.net/view/photo/s_ratio_poster/public/p1.jpg")
    }

    @Test
    fun resolve_direct_keeps_original() {
        val original = "https://img2.doubanio.com/view/photo/s_ratio_poster/public/p1.jpg"
        assertThat(resolveDoubanImageUrl(original, "direct")).isEqualTo(original)
    }

    @Test
    fun resolve_non_douban_url_keeps_original() {
        val original = "https://cdn.example.com/cover.jpg"
        assertThat(resolveDoubanImageUrl(original, "official_cdn")).isEqualTo(original)
    }

    @Test
    fun normalize_image_source_key_accepts_chinese_aliases() {
        assertThat(normalizeImageSourceKey("直连")).isEqualTo("direct")
        assertThat(normalizeImageSourceKey("官方精品")).isEqualTo("official_cdn")
        assertThat(normalizeImageSourceKey("腾讯CDN")).isEqualTo("tencent_cdn")
        assertThat(normalizeImageSourceKey("阿里CDN")).isEqualTo("alibaba_cdn")
    }
}
