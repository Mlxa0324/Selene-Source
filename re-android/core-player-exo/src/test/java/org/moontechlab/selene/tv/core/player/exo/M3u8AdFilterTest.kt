package org.moontechlab.selene.tv.core.player.exo

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 M3U8 去广告过滤契约。
 */
class M3u8AdFilterTest {
    @Test
    fun looksLikeM3u8Url_detects_common_paths() {
        assertThat(M3u8AdFilter.looksLikeM3u8Url("https://cdn.test/index.m3u8")).isTrue()
        assertThat(M3u8AdFilter.looksLikeM3u8Url("https://cdn.test/video.mp4")).isFalse()
    }

    @Test
    fun filter_removes_discontinuity_markers_and_rewrites_relative_segments() {
        val content = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXTINF:4.0,
            seg0.ts
            #EXT-X-DISCONTINUITY
            #EXTINF:4.0,
            seg1.ts
        """.trimIndent()

        val filtered = M3u8AdFilter.filterAdsFromM3u8(
            content = content,
            baseUrl = "https://cdn.test/play/index.m3u8",
        )

        // 对齐 Flutter：剥离广告标记行，相对分片改写为绝对地址。
        assertThat(filtered).doesNotContain("#EXT-X-DISCONTINUITY")
        assertThat(filtered).contains("https://cdn.test/play/seg0.ts")
        assertThat(filtered).contains("https://cdn.test/play/seg1.ts")
    }

    @Test
    fun filter_skips_explicit_cue_out_ad_blocks() {
        val content = """
            #EXTM3U
            #EXTINF:4.0,
            seg0.ts
            #EXT-X-CUE-OUT:30
            #EXTINF:2.0,
            ad.ts
            #EXT-X-CUE-IN
            #EXTINF:4.0,
            seg1.ts
        """.trimIndent()

        val filtered = M3u8AdFilter.filterAdsFromM3u8(
            content = content,
            baseUrl = "https://cdn.test/play/index.m3u8",
        )

        assertThat(filtered).doesNotContain("ad.ts")
        assertThat(filtered).contains("https://cdn.test/play/seg0.ts")
        assertThat(filtered).contains("https://cdn.test/play/seg1.ts")
    }
}
