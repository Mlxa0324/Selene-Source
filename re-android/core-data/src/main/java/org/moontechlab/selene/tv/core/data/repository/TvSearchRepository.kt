package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvSearchPayload

/**
 * TV 搜索仓库。
 */
class TvSearchRepository {
    /**
     * 搜索影视内容。
     *
     * @param query 搜索关键词。
     * @return 搜索结果载荷。
     */
    suspend fun search(query: String): TvSearchPayload {
        // 首期先保留接口契约，用于对齐 Flutter TV 搜索历史、热词和推荐链路。
        return TvSearchPayload(query = query, results = emptyList())
    }
}
