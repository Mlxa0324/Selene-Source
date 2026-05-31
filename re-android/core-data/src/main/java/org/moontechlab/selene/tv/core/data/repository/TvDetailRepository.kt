package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvVideoDetail

/**
 * TV 详情仓库。
 */
class TvDetailRepository {
    /**
     * 读取影视详情。
     *
     * @param videoId 影视 ID。
     * @return 影视详情；首期未接入详情接口时返回 null。
     */
    suspend fun loadDetail(videoId: String): TvVideoDetail? {
        // 详情页按首屏可播源、后台补源和推荐三段加载组织状态。
        return null
    }
}
