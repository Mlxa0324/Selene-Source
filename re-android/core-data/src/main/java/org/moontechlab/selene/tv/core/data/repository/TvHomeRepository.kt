package org.moontechlab.selene.tv.core.data.repository

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.moontechlab.selene.tv.core.data.model.TvHomePayload
import org.moontechlab.selene.tv.core.data.model.TvHomeSection
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * TV 首页数据仓库。
 *
 * 首页各分区与分类 Tab 共用 [DoubanRepository] 的同一份 LRU 缓存，
 * 确保首页卡片和对应分类页首屏数据一致、不重复请求。
 *
 * 各分区并行请求，先完成的分区先回填，避免等全部接口结束后再整页渲染。
 *
 * @property playbackRepository 播放记录仓库。
 * @property doubanRepository 豆瓣数据仓库（与分类页共享）。
 * @property bangumiRepository Bangumi 新番放送仓库。
 */
class TvHomeRepository(
    private val playbackRepository: TvPlaybackRepository,
    private val doubanRepository: DoubanRepository,
    private val bangumiRepository: BangumiRepository? = null,
) {
    /**
     * 加载 TV 首页聚合数据（一次性完整结果）。
     *
     * 内部复用流式加载，取最后一次完整快照。
     *
     * @return 包含继续观看和四个内容分区的首页载荷。
     */
    suspend fun loadHome(): TvHomePayload {
        return observeHome().first { progress -> progress.isComplete }.payload
    }

    /**
     * 按块观察首页分区加载进度。
     *
     * 四个内容分区与继续观看并行请求；任一分区完成即发射当前已就绪快照，
     * 最终一次 `isComplete=true` 表示全部请求结束。
     *
     * @return 渐进式首页加载进度流。
     */
    fun observeHome(): Flow<TvHomeLoadProgress> = channelFlow {
        // 已完成分区缓存：key -> section。
        val readySections = linkedMapOf<String, TvHomeSection>()
        val mutex = Mutex()

        /**
         * 组装当前已就绪分区快照。
         *
         * @return 按固定顺序排列、过滤空继续观看后的分区列表。
         */
        fun snapshotSections(): List<TvHomeSection> {
            return SECTION_ORDER.mapNotNull { key -> readySections[key] }
                .filterNot { section ->
                    section.key == CONTINUE_WATCHING_KEY && section.videos.isEmpty()
                }
        }

        /**
         * 写入单个分区结果并立刻回填 UI。
         *
         * @param section 完成的分区。
         */
        suspend fun completeSection(section: TvHomeSection) {
            val sections = mutex.withLock {
                readySections[section.key] = section
                snapshotSections()
            }
            // 先到先发射：不锁 send，避免与 mutex 嵌套死锁。
            send(
                TvHomeLoadProgress(
                    payload = TvHomePayload(sections = sections),
                    isComplete = false,
                ),
            )
        }

        coroutineScope {
            // 继续观看：本地/网关记录，通常较快，单独一块回填。
            launch(Dispatchers.IO) {
                val continueWatching = runCatching {
                    playbackRepository.readContinueWatching()
                }.getOrDefault(emptyList())
                // 无记录时不占位，与旧版“隐藏继续观看”一致。
                if (continueWatching.isNotEmpty()) {
                    completeSection(
                        TvHomeSection(
                            key = CONTINUE_WATCHING_KEY,
                            title = CONTINUE_WATCHING_TITLE,
                            videos = continueWatching,
                        ),
                    )
                }
            }

            // 热门电影。
            launch(Dispatchers.IO) {
                completeSection(
                    TvHomeSection(
                        key = HOT_MOVIES_KEY,
                        title = HOT_MOVIES_TITLE,
                        videos = loadCategorySafely(
                            DoubanCategoryParams(kind = "movie", category = "热门"),
                        ),
                    ),
                )
            }

            // 热门剧集。
            launch(Dispatchers.IO) {
                completeSection(
                    TvHomeSection(
                        key = HOT_TV_SHOWS_KEY,
                        title = HOT_TV_SHOWS_TITLE,
                        videos = loadCategorySafely(
                            DoubanCategoryParams(kind = "tv", category = "最近热门", type = "tv"),
                        ),
                    ),
                )
            }

            // 新番放送：对齐 Flutter，走 Bangumi 当日日历。
            launch(Dispatchers.IO) {
                completeSection(
                    TvHomeSection(
                        key = BANGUMI_CALENDAR_KEY,
                        title = BANGUMI_CALENDAR_TITLE,
                        videos = loadBangumiCalendarSafely(),
                    ),
                )
            }

            // 热门综艺。
            launch(Dispatchers.IO) {
                completeSection(
                    TvHomeSection(
                        key = HOT_SHOWS_KEY,
                        title = HOT_SHOWS_TITLE,
                        videos = loadCategorySafely(
                            DoubanCategoryParams(kind = "tv", category = "show", type = "show"),
                        ),
                    ),
                )
            }
        }

        // 全部子任务结束后发完整快照，供 ViewModel 结束 loading。
        val finalSections = mutex.withLock { snapshotSections() }
        send(
            TvHomeLoadProgress(
                payload = TvHomePayload(sections = finalSections),
                isComplete = true,
            ),
        )
    }

    /**
     * 安全加载豆瓣分类，失败时返回空列表，不阻断其它分区。
     *
     * @param params 分类参数。
     * @return 视频卡片列表。
     */
    private suspend fun loadCategorySafely(params: DoubanCategoryParams): List<TvVideoCard> {
        return runCatching {
            doubanRepository.loadCategory(params)
        }.getOrDefault(emptyList())
    }

    /**
     * 安全加载 Bangumi 当日新番，失败返回空列表，不阻断其它分区。
     *
     * @return 今日放送卡片列表。
     */
    private suspend fun loadBangumiCalendarSafely(): List<TvVideoCard> {
        val repository = bangumiRepository ?: return emptyList()
        return runCatching {
            repository.loadTodayCalendar()
        }.getOrDefault(emptyList())
    }

    private companion object {
        /** 继续观看分区标识。 */
        const val CONTINUE_WATCHING_KEY = "continue_watching"

        /** 继续观看分区标题。 */
        const val CONTINUE_WATCHING_TITLE = "继续观看"

        /** 热门电影分区标识。 */
        const val HOT_MOVIES_KEY = "hot_movies"

        /** 热门电影分区标题。 */
        const val HOT_MOVIES_TITLE = "热门电影"

        /** 热门剧集分区标识。 */
        const val HOT_TV_SHOWS_KEY = "hot_tv_shows"

        /** 热门剧集分区标题。 */
        const val HOT_TV_SHOWS_TITLE = "热门剧集"

        /** 新番放送分区标识。 */
        const val BANGUMI_CALENDAR_KEY = "bangumi_calendar"

        /** 新番放送分区标题。 */
        const val BANGUMI_CALENDAR_TITLE = "新番放送"

        /** 热门综艺分区标识。 */
        const val HOT_SHOWS_KEY = "hot_shows"

        /** 热门综艺分区标题。 */
        const val HOT_SHOWS_TITLE = "热门综艺"

        /** 首页分区固定展示顺序。 */
        val SECTION_ORDER = listOf(
            CONTINUE_WATCHING_KEY,
            HOT_MOVIES_KEY,
            HOT_TV_SHOWS_KEY,
            BANGUMI_CALENDAR_KEY,
            HOT_SHOWS_KEY,
        )
    }
}

/**
 * 首页流式加载进度。
 *
 * @property payload 当前已就绪分区快照（按固定顺序）。
 * @property isComplete 是否所有分区请求均已结束。
 */
data class TvHomeLoadProgress(
    val payload: TvHomePayload,
    val isComplete: Boolean,
)
