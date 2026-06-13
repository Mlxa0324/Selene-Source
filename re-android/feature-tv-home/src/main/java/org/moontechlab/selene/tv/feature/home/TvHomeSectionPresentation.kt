package org.moontechlab.selene.tv.feature.home

import org.moontechlab.selene.tv.core.data.model.TvHomeSection
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * 首页横向分区最大展示视频数量。
 */
const val TV_HOME_MAX_VISIBLE_VIDEOS = 15

/**
 * TV 首页分区更多入口目标。
 */
enum class TvHomeSectionMoreTarget {
    /** 播放历史页。 */
    History,

    /** 电影分类页。 */
    Movie,

    /** 剧集分类页。 */
    Tv,

    /** 动漫分类页。 */
    Anime,

    /** 综艺分类页。 */
    Show,

    /** 收藏夹页。 */
    Favorites,
}

/**
 * TV 首页分区展示模型。
 *
 * @property visibleVideos 首屏横向列表实际展示的视频。
 * @property showMore 是否在列表尾部展示更多入口。
 * @property moreTarget 更多入口跳转目标。
 */
data class TvHomeSectionPresentation(
    val visibleVideos: List<TvVideoCard>,
    val showMore: Boolean,
    val moreTarget: TvHomeSectionMoreTarget?,
)

/**
 * 将首页接口分区转成首屏展示模型。
 *
 * @return 控制可见视频数量和更多入口的展示模型。
 */
fun TvHomeSection.toHomeSectionPresentation(): TvHomeSectionPresentation {
    val moreTarget = homeSectionMoreTargetFor(key)
    val showMore = videos.size > TV_HOME_MAX_VISIBLE_VIDEOS && moreTarget != null
    return TvHomeSectionPresentation(
        visibleVideos = videos.take(TV_HOME_MAX_VISIBLE_VIDEOS),
        showMore = showMore,
        moreTarget = moreTarget.takeIf { showMore },
    )
}

/**
 * 获取首页分区更多入口目标。
 *
 * @param sectionKey 首页分区标识。
 * @return 可跳转的更多入口目标，未知分区返回空。
 */
fun homeSectionMoreTargetFor(sectionKey: String): TvHomeSectionMoreTarget? {
    return when (sectionKey) {
        "continue_watching",
        "history",
        -> TvHomeSectionMoreTarget.History
        "hot_movies" -> TvHomeSectionMoreTarget.Movie
        "hot_tv_shows" -> TvHomeSectionMoreTarget.Tv
        "bangumi_calendar" -> TvHomeSectionMoreTarget.Anime
        "hot_shows" -> TvHomeSectionMoreTarget.Show
        "favorites" -> TvHomeSectionMoreTarget.Favorites
        else -> null
    }
}
