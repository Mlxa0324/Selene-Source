package uk.oxiang.ivy.tv.core.common.repository

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import uk.oxiang.ivy.tv.core.common.model.TvHomePayload
import uk.oxiang.ivy.tv.core.common.model.TvHomeSection

/**
 * TV 首页数据仓库。
 *
 * 首页各分区与分类 Tab 共用 [DoubanRepository] 的同一份 LRU 缓存，
 * 确保首页卡片和对应分类页首屏数据一致、不重复请求。
 *
 * @property playbackRepository 播放记录仓库。
 * @property doubanRepository 豆瓣数据仓库（与分类页共享）。
 */
class TvHomeRepository(
    private val playbackRepository: TvPlaybackRepository,
    private val doubanRepository: DoubanRepository,
) {
    /**
     * 加载 TV 首页聚合数据。
     *
     * 四个内容分区并行请求 Douban 代理 API，参数 1:1 对齐各分类 Tab 默认筛选：
     * - 热门电影 → Movie Tab 简单模式 (kind=movie, category=热门)
     * - 热门剧集 → TV Tab 简单模式 (kind=tv, category=最近热门)
     * - 新番放送 → Anime Tab 番剧模式 (kind=tv, type=动画, format=电视剧)
     * - 热门综艺 → Variety Tab 简单模式 (kind=tv, category=show, type=show)
     *
     * @return 包含继续观看和四个内容分区的首页载荷。
     */
    suspend fun loadHome(): TvHomePayload = coroutineScope {
        // 继续观看：始终从播放记录仓库取，与播放历史 Tab 共用数据源
        val continueWatching = runCatching {
            playbackRepository.readContinueWatching()
        }.getOrDefault(emptyList())

        // ── 四个内容分区：并行请求，参数与分类 Tab 默认完全一致 ──

        val hotMovies = async(Dispatchers.IO) {
            runCatching {
                doubanRepository.loadCategory(
                    DoubanCategoryParams(kind = "movie", category = "热门"),
                )
            }.getOrDefault(emptyList())
        }

        val hotTvShows = async(Dispatchers.IO) {
            runCatching {
                doubanRepository.loadCategory(
                    DoubanCategoryParams(kind = "tv", category = "最近热门", type = "tv"),
                )
            }.getOrDefault(emptyList())
        }

        val bangumiCalendar = async(Dispatchers.IO) {
            runCatching {
                // 新番放送 = 动漫 Tab 番剧推荐，后续接入 Bangumi 后可改为每日放送日历
                doubanRepository.loadCategory(
                    DoubanCategoryParams(
                        kind = "tv",
                        category = "全部",
                        type = "动画",
                        format = "电视剧",
                    ),
                )
            }.getOrDefault(emptyList())
        }

        val hotShows = async(Dispatchers.IO) {
            runCatching {
                doubanRepository.loadCategory(
                    DoubanCategoryParams(kind = "tv", category = "show", type = "show"),
                )
            }.getOrDefault(emptyList())
        }

        TvHomePayload(
            sections = listOfNotNull(
                // 继续观看：无记录时隐藏
                TvHomeSection(
                    key = CONTINUE_WATCHING_KEY,
                    title = CONTINUE_WATCHING_TITLE,
                    videos = continueWatching,
                ).takeIf { continueWatching.isNotEmpty() },
                TvHomeSection(
                    key = "hot_movies",
                    title = "热门电影",
                    videos = hotMovies.await(),
                ),
                TvHomeSection(
                    key = "hot_tv_shows",
                    title = "热门剧集",
                    videos = hotTvShows.await(),
                ),
                TvHomeSection(
                    key = "bangumi_calendar",
                    title = "新番放送",
                    videos = bangumiCalendar.await(),
                ),
                TvHomeSection(
                    key = "hot_shows",
                    title = "热门综艺",
                    videos = hotShows.await(),
                ),
            ),
        )
    }

    private companion object {
        /** 继续观看分区标识。 */
        const val CONTINUE_WATCHING_KEY = "continue_watching"

        /** 继续观看分区标题。 */
        const val CONTINUE_WATCHING_TITLE = "继续观看"
    }
}
