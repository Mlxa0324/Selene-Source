package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 TV 海报列表渲染 key。
 */
class TvPosterItemKeyTest {
    /**
     * 重复业务 ID 应生成不同 UI key，避免 Compose Lazy 列表崩溃。
     */
    @Test
    fun posterListItemKey_keepsDuplicateBusinessIdsUnique() {
        val first = TvPosterItem(id = "84822", title = "同名内容")
        val second = TvPosterItem(id = "84822", title = "同名内容")

        val firstKey = posterListItemKey(index = 0, item = first)
        val secondKey = posterListItemKey(index = 1, item = second)

        assertThat(firstKey).isEqualTo("poster:84822:0")
        assertThat(secondKey).isEqualTo("poster:84822:1")
        assertThat(firstKey).isNotEqualTo(secondKey)
    }

    /**
     * 播放进度应被限制在进度条可渲染范围内。
     */
    @Test
    fun normalizedPosterProgress_clampsInvalidValues() {
        assertThat(normalizedPosterProgress(-0.2f)).isEqualTo(0f)
        assertThat(normalizedPosterProgress(0.45f)).isEqualTo(0.45f)
        assertThat(normalizedPosterProgress(1.4f)).isEqualTo(1f)
        assertThat(normalizedPosterProgress(Float.NaN)).isEqualTo(0f)
    }

    /**
     * 视频身份 key 应保留 source，支持详情页精准请求。
     */
    @Test
    fun toVideoIdentityKey_keeps_source_and_id() {
        val item = TvPosterItem(
            id = "video-1",
            source = "source-a",
            title = "测试影片",
        )

        assertThat(item.toVideoIdentityKey()).isEqualTo("source-a::video-1")
    }
}
