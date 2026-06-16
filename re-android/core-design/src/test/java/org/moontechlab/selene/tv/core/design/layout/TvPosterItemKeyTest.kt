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
}
