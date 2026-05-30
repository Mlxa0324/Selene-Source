package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvHomePayload
import org.moontechlab.selene.tv.core.data.model.TvHomeSection
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.SeleneTvApi
import org.moontechlab.selene.tv.core.network.model.TvHomeResponse
import org.moontechlab.selene.tv.core.network.model.TvHomeSectionResponse
import org.moontechlab.selene.tv.core.network.model.TvVideoCardResponse

/**
 * TV 首页数据仓库。
 *
 * @property api TV 服务端接口。
 * @property playbackRepository 播放记录仓库。
 */
class TvHomeRepository(
    private val api: SeleneTvApi,
    private val playbackRepository: TvPlaybackRepository,
) {
    /**
     * 加载 TV 首页聚合数据。
     *
     * @return 包含继续观看和远端热门分区的首页载荷。
     */
    suspend fun loadHome(): TvHomePayload {
        val remote = api.getDashboard()
        val continueWatching = playbackRepository.readContinueWatching()
        return remote.toHomePayload(continueWatching = continueWatching)
    }

    /**
     * 将接口响应转换为 TV 首页业务模型。
     *
     * @param continueWatching 本地继续观看列表。
     * @return 可直接供首页 ViewModel 使用的聚合载荷。
     */
    private fun TvHomeResponse.toHomePayload(
        continueWatching: List<TvVideoCard>,
    ): TvHomePayload {
        val sections = buildList {
            // 继续观看始终放在远端分区前，保持 Flutter TV 首页浏览顺序。
            add(
                TvHomeSection(
                    key = CONTINUE_WATCHING_KEY,
                    title = CONTINUE_WATCHING_TITLE,
                    videos = continueWatching,
                ),
            )
            // 远端首页分区保持服务端顺序，避免二次排序影响首页习惯。
            addAll(sections.map { section -> section.toModel() })
        }
        return TvHomePayload(sections = sections)
    }

    /**
     * 将接口分区响应转换为业务分区。
     *
     * @return 首页业务分区。
     */
    private fun TvHomeSectionResponse.toModel(): TvHomeSection {
        return TvHomeSection(
            key = key,
            title = title,
            videos = videos.map { video -> video.toModel() },
        )
    }

    /**
     * 将接口视频响应转换为业务卡片。
     *
     * @return TV 影视卡片模型。
     */
    private fun TvVideoCardResponse.toModel(): TvVideoCard {
        return TvVideoCard(
            id = id,
            title = title,
            posterUrl = posterUrl,
        )
    }

    private companion object {
        /** 继续观看分区标识。 */
        const val CONTINUE_WATCHING_KEY = "continue_watching"

        /** 继续观看分区标题。 */
        const val CONTINUE_WATCHING_TITLE = "继续观看"
    }
}
