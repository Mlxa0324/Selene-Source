package org.moontechlab.selene.tv.feature.home

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flow
import org.moontechlab.selene.tv.core.data.model.TvHomePayload
import org.moontechlab.selene.tv.core.data.model.TvHomeSection
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * TV 首页界面状态。
 *
 * @property selectedMainTab 当前主菜单选中项。
 * @property sections 首页分区列表。
 * @property isLoading 是否正在加载首页数据。
 * @property errorMessage 首页加载失败文案。
 */
data class TvHomeUiState(
    val selectedMainTab: String = HOME_TAB_KEY,
    val sections: List<TvHomeSection> = emptyList(),
    /**
     * 是否仍在拉取首页数据。
     *
     * 流式加载下：首个分区已回填时仍可能为 true，便于骨架/局部占位策略判断。
     */
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

/**
 * TV 视频库筛选选项。
 *
 * @property key 筛选选项标识。
 * @property title 筛选选项标题。
 * @property apiValue 对应的豆瓣 API 值（默认与 key 一致）。
 */
data class TvLibraryFilterOption(
    val key: String,
    val title: String,
    val apiValue: String = key,
)

/**
 * TV 视频库筛选项。
 *
 * @property key 筛选行标识。
 * @property title 筛选行标题。
 * @property options 筛选行可选项。
 * @property selectedOptionKey 当前确认选项标识。
 * @property focusedOptionKey 当前焦点选项标识。
 */
data class TvLibraryFilter(
    val key: String,
    val title: String,
    val options: List<TvLibraryFilterOption>,
    val selectedOptionKey: String = options.firstOrNull()?.key.orEmpty(),
    val focusedOptionKey: String = selectedOptionKey,
) {
    /** 当前确认选项。 */
    val selectedOption: TvLibraryFilterOption
        get() = optionFor(selectedOptionKey)

    /** 当前焦点选项。 */
    val focusedOption: TvLibraryFilterOption
        get() = optionFor(focusedOptionKey)

    /**
     * 选中指定筛选选项。
     *
     * @param optionKey 筛选选项标识。
     * @return 更新后的筛选行。
     */
    fun selectOption(optionKey: String): TvLibraryFilter {
        val option = optionFor(optionKey)
        return copy(
            selectedOptionKey = option.key,
            focusedOptionKey = option.key,
        )
    }

    /**
     * 记录当前筛选焦点。
     *
     * @param optionKey 筛选选项标识。
     * @return 更新后的筛选行。
     */
    fun focusOption(optionKey: String): TvLibraryFilter {
        val option = optionFor(optionKey)
        return copy(focusedOptionKey = option.key)
    }

    /**
     * 查找筛选选项，未命中时回退到首项。
     *
     * @param optionKey 筛选选项标识。
     * @return 可展示的筛选选项。
     */
    private fun optionFor(optionKey: String): TvLibraryFilterOption {
        return options.firstOrNull { option -> option.key == optionKey }
            ?: options.firstOrNull()
            ?: TvLibraryFilterOption(key = "", title = "全部")
    }
}

/**
 * TV 视频网格焦点移动方向。
 */
enum class TvGridFocusDirection {
    /** 左方向。 */
    Left,

    /** 右方向。 */
    Right,

    /** 上方向。 */
    Up,

    /** 下方向。 */
    Down,
}

/**
 * TV 视频库界面状态。
 *
 * @property categoryKey 当前分类标识。
 * @property title 当前分类标题。
 * @property availableFilters 可用筛选项。
 * @property videos 当前分类视频列表。
 * @property gridColumns 视频网格列数。
 * @property isLoading 是否正在加载。
 * @property errorMessage 错误文案。
 */
data class TvVideoLibraryUiState(
    val categoryKey: String,
    val title: String,
    val availableFilters: List<TvLibraryFilter>,
    val videos: List<TvVideoCard> = emptyList(),
    val gridColumns: Int = DEFAULT_LIBRARY_GRID_COLUMNS,
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = true,
    val currentPage: Int = 0,
    val errorMessage: String? = null,
) {
    /** 已选筛选摘要。 */
    val selectedFilterSummary: String
        get() = availableFilters.joinToString(" / ") { filter ->
            "${filter.title} ${filter.selectedOption.title}"
        }

    /**
     * 选中指定筛选项。
     *
     * @param filterKey 筛选行标识。
     * @param optionKey 筛选选项标识。
     * @return 更新后的分类页状态。
     */
    fun selectFilterOption(filterKey: String, optionKey: String): TvVideoLibraryUiState {
        return copy(
            availableFilters = availableFilters.map { filter ->
                if (filter.key == filterKey) {
                    // 确认筛选后同步焦点，保持遥控器停留在刚确认的选项上。
                    filter.selectOption(optionKey)
                } else {
                    filter
                }
            },
        )
    }

    /**
     * 记录筛选面板当前焦点。
     *
     * @param filterKey 筛选行标识。
     * @param optionKey 筛选选项标识。
     * @return 更新后的分类页状态。
     */
    fun focusFilterOption(filterKey: String, optionKey: String): TvVideoLibraryUiState {
        return copy(
            availableFilters = availableFilters.map { filter ->
                if (filter.key == filterKey) {
                    filter.focusOption(optionKey)
                } else {
                    filter
                }
            },
        )
    }

    /**
     * 计算视频网格下一焦点下标。
     *
     * @param currentIndex 当前焦点下标。
     * @param direction 移动方向。
     * @return 下一焦点下标。
     */
    fun nextGridFocusIndex(currentIndex: Int, direction: TvGridFocusDirection): Int {
        return nextLibraryGridFocusIndex(
            currentIndex = currentIndex,
            itemCount = videos.size,
            columns = gridColumns,
            direction = direction,
        )
    }

    companion object {
        /**
         * 根据顶部主菜单分类创建视频库默认状态。
         *
         * @param categoryKey 分类标识。
         * @return 视频库初始状态。
         */
        fun forCategory(categoryKey: String): TvVideoLibraryUiState {
            return TvVideoLibraryUiState(
                categoryKey = categoryKey,
                title = categoryTitle(categoryKey),
                availableFilters = defaultLibraryFiltersFor(categoryKey),
            )
        }

        /**
         * 获取分类标题。
         *
         * @param categoryKey 分类标识。
         * @return 中文展示标题。
         */
        private fun categoryTitle(categoryKey: String): String {
            return when (categoryKey) {
                "movie" -> "电影"
                "tv" -> "剧集"
                "anime" -> "动漫"
                "show" -> "综艺"
                else -> "视频库"
            }
        }
    }
}

/**
 * TV 首页 ViewModel。
 *
 * 支持一次性 [loadHome] 与流式 [observeHome] 两种注入：
 * 优先使用 observeHome，哪个分区先返回就先展示哪块。
 *
 * @property loadHome 首页一次性加载函数（兼容旧测试与兜底）。
 * @property loadContinueWatching 继续观看分区单独刷新函数。
 * @property observeHome 首页分区流式加载函数；返回 null 时退回 loadHome。
 */
class TvHomeViewModel(
    private val loadHome: suspend () -> TvHomePayload,
    private val loadContinueWatching: suspend () -> List<TvVideoCard> = { emptyList() },
    private val observeHome: (() -> Flow<TvHomeSectionProgress>)? = null,
) {
    /** 首页内部状态。 */
    private val mutableState = MutableStateFlow(TvHomeUiState())

    /** 首页公开状态。 */
    val state: StateFlow<TvHomeUiState> = mutableState

    /**
     * 加载首页数据。
     *
     * 有流式数据源时按块回填；否则保持整包加载语义。
     */
    suspend fun load() {
        // 加载过程只更新数据状态，不改变当前主菜单选中项。
        mutableState.value = mutableState.value.copy(
            isLoading = true,
            errorMessage = null,
        )
        val stream = observeHome
        if (stream != null) {
            runCatching {
                stream().collect { progress ->
                    // 先到先显示：只合并当前已就绪分区，保持 Flutter TV 固定顺序。
                    mutableState.value = mutableState.value.copy(
                        sections = progress.sections.normalizedForFlutterTvHome(
                            onlyReadyKeys = progress.readyKeys,
                        ),
                        selectedMainTab = HOME_TAB_KEY,
                        isLoading = !progress.isComplete,
                        errorMessage = null,
                    )
                }
            }.onFailure { throwable ->
                mutableState.value = mutableState.value.copy(
                    isLoading = false,
                    errorMessage = throwable.message ?: "首页数据加载失败",
                )
            }
            return
        }

        runCatching { loadHome() }
            .onSuccess { payload ->
                mutableState.value = mutableState.value.copy(
                    sections = payload.sections.normalizedForFlutterTvHome(),
                    selectedMainTab = HOME_TAB_KEY,
                    isLoading = false,
                    errorMessage = null,
                )
            }
            .onFailure { throwable ->
                // 加载失败保留旧数据并退出 loading，避免页面卡死在转圈状态。
                mutableState.value = mutableState.value.copy(
                    isLoading = false,
                    errorMessage = throwable.message ?: "首页数据加载失败",
                )
            }
    }

    /**
     * 单独刷新继续观看分区。
     *
     * 返回首页时只更新续播块，避免整页重新清空后闪动。
     */
    suspend fun refreshContinueWatching() {
        runCatching { loadContinueWatching() }
            .onSuccess { videos ->
                val latestState = mutableState.value
                mutableState.value = latestState.copy(
                    sections = latestState.sections.withContinueWatchingVideos(videos),
                )
            }
            .onFailure {
                // 局部续播刷新失败时保留当前首页内容，不额外打断用户浏览。
            }
    }
}

/**
 * 首页分区流式进度。
 *
 * @property sections 当前已就绪分区（可无序）。
 * @property readyKeys 已回填分区 key，用于避免补齐未加载空分区。
 * @property isComplete 是否全部请求结束。
 */
data class TvHomeSectionProgress(
    val sections: List<TvHomeSection>,
    val readyKeys: Set<String>,
    val isComplete: Boolean,
)

/**
 * TV 分类视频库 ViewModel。
 *
 * @property categoryKey 分类标识。
 * @property loadCategory 分类数据加载函数。
 */
class TvVideoLibraryViewModel(
    categoryKey: String,
    private val loadCategory: suspend (categoryKey: String, filters: List<TvLibraryFilter>, page: Int) -> List<TvVideoCard>,
) {
    /** 分类内部状态。 */
    private val mutableState = MutableStateFlow(TvVideoLibraryUiState.forCategory(categoryKey))

    /** 分类公开状态。 */
    val state: StateFlow<TvVideoLibraryUiState> = mutableState

    /**
     * 加载分类首页数据（page=0）。
     */
    suspend fun load() {
        val currentState = mutableState.value
        mutableState.value = currentState.copy(
            isLoading = true,
            currentPage = 0,
            hasMore = true,
            errorMessage = null,
        )
        runCatching { loadCategory(currentState.categoryKey, currentState.availableFilters, 0) }
            .onSuccess { videos ->
                mutableState.value = currentState.copy(
                    videos = videos,
                    currentPage = 0,
                    hasMore = videos.isNotEmpty(),
                    isLoading = false,
                    errorMessage = null,
                )
            }
            .onFailure { throwable ->
                mutableState.value = TvVideoLibraryUiState.forCategory(currentState.categoryKey).copy(
                    isLoading = false,
                    errorMessage = throwable.message ?: "分类内容加载失败",
                )
            }
    }

    /**
     * 触底加载下一页，追加到现有列表。
     */
    suspend fun loadNextPage() {
        val s = mutableState.value
        if (!s.hasMore || s.isLoadingMore || s.isLoading) return
        val nextPage = s.currentPage + 1
        mutableState.value = s.copy(isLoadingMore = true)
        runCatching { loadCategory(s.categoryKey, s.availableFilters, nextPage) }
            .onSuccess { newVideos ->
                mutableState.value = mutableState.value.copy(
                    videos = s.videos + newVideos,
                    currentPage = nextPage,
                    hasMore = newVideos.isNotEmpty(),
                    isLoadingMore = false,
                )
            }
            .onFailure {
                mutableState.value = mutableState.value.copy(isLoadingMore = false)
            }
    }

    /**
     * 选中筛选选项并重新加载首页数据。
     */
    fun applyFilter(filterKey: String, optionKey: String) {
        val updated = mutableState.value.selectFilterOption(filterKey, optionKey)
        val newSelectedOptions = updated.availableFilters.associate { f -> f.key to f.selectedOptionKey }
        mutableState.value = updated.copy(
            availableFilters = defaultLibraryFiltersFor(updated.categoryKey, newSelectedOptions),
            currentPage = 0,
            hasMore = true,
        )
    }

    /**
     * 记录筛选面板的当前焦点，不改变已确认筛选条件或触发数据刷新。
     *
     * @param filterKey 筛选行标识。
     * @param optionKey 当前焦点选项标识。
     */
    fun focusFilter(filterKey: String, optionKey: String) {
        // 遥控器浏览仅更新焦点记忆，确认键才调用 applyFilter 修改查询参数。
        mutableState.value = mutableState.value.focusFilterOption(filterKey, optionKey)
    }
}

/** 首页主菜单标识。 */
const val HOME_TAB_KEY = "home"

/** 视频库默认网格列数。 */
private const val DEFAULT_LIBRARY_GRID_COLUMNS = 5

/**
 * Flutter TV 首页固定分区顺序。
 */
private val HOME_SECTION_TEMPLATES = listOf(
    TvHomeSection(key = "continue_watching", title = "继续观看", videos = emptyList()),
    TvHomeSection(key = "hot_movies", title = "热门电影", videos = emptyList()),
    TvHomeSection(key = "hot_tv_shows", title = "热门剧集", videos = emptyList()),
    TvHomeSection(key = "bangumi_calendar", title = "新番放送", videos = emptyList()),
    TvHomeSection(key = "hot_shows", title = "热门综艺", videos = emptyList()),
)

// ── 筛选选项（1:1 对齐 Flutter TV TvCategoryFilterOptions）──

/** 电影分类选项。 */
private val MOVIE_CLASS_OPTIONS = listOf(
    TvLibraryFilterOption(key = "全部", title = "全部", apiValue = "全部"),
    TvLibraryFilterOption(key = "热门", title = "热门电影", apiValue = "热门"),
    TvLibraryFilterOption(key = "最新", title = "最新电影", apiValue = "最新"),
    TvLibraryFilterOption(key = "豆瓣高分", title = "豆瓣高分", apiValue = "豆瓣高分"),
    TvLibraryFilterOption(key = "冷门佳片", title = "冷门佳片", apiValue = "冷门佳片"),
)

/** 电影简单地区选项（simple mode 专用）。 */
private val MOVIE_SIMPLE_REGION_OPTIONS = listOf(
    TvLibraryFilterOption(key = "全部", title = "全部", apiValue = "全部"),
    TvLibraryFilterOption(key = "华语", title = "华语", apiValue = "华语"),
    TvLibraryFilterOption(key = "欧美", title = "欧美", apiValue = "欧美"),
    TvLibraryFilterOption(key = "韩国", title = "韩国", apiValue = "韩国"),
    TvLibraryFilterOption(key = "日本", title = "日本", apiValue = "日本"),
)

/** 剧集分类选项。 */
private val TV_CLASS_OPTIONS = listOf(
    TvLibraryFilterOption(key = "全部", title = "全部", apiValue = "全部"),
    TvLibraryFilterOption(key = "最近热门", title = "最近热门", apiValue = "最近热门"),
)

/** 剧集简单类型选项（simple mode 专用）。 */
private val SERIES_SIMPLE_TYPE_OPTIONS = listOf(
    TvLibraryFilterOption(key = "tv", title = "全部", apiValue = "tv"),
    TvLibraryFilterOption(key = "tv_domestic", title = "国产", apiValue = "tv_domestic"),
    TvLibraryFilterOption(key = "tv_american", title = "欧美", apiValue = "tv_american"),
    TvLibraryFilterOption(key = "tv_japanese", title = "日本", apiValue = "tv_japanese"),
    TvLibraryFilterOption(key = "tv_korean", title = "韩国", apiValue = "tv_korean"),
    TvLibraryFilterOption(key = "tv_animation", title = "动漫", apiValue = "tv_animation"),
    TvLibraryFilterOption(key = "tv_documentary", title = "纪录片", apiValue = "tv_documentary"),
)

/** 综艺分类选项。 */
private val SHOW_CLASS_OPTIONS = listOf(
    TvLibraryFilterOption(key = "全部", title = "全部", apiValue = "全部"),
    TvLibraryFilterOption(key = "最近热门", title = "最近热门", apiValue = "最近热门"),
)

/** 综艺简单类型选项（simple mode 专用）。 */
private val VARIETY_SIMPLE_TYPE_OPTIONS = listOf(
    TvLibraryFilterOption(key = "show", title = "全部", apiValue = "show"),
    TvLibraryFilterOption(key = "show_domestic", title = "国内", apiValue = "show_domestic"),
    TvLibraryFilterOption(key = "show_foreign", title = "国外", apiValue = "show_foreign"),
)

/** 动漫分类选项。 */
private val ANIME_CLASS_OPTIONS = listOf(
    TvLibraryFilterOption(key = "每日放送", title = "每日放送", apiValue = "每日放送"),
    TvLibraryFilterOption(key = "番剧", title = "番剧", apiValue = "番剧"),
    TvLibraryFilterOption(key = "剧场版", title = "剧场版", apiValue = "剧场版"),
)

/** 动漫周几选项。 */
private val WEEKDAY_OPTIONS = listOf(
    TvLibraryFilterOption(key = "1", title = "周一", apiValue = "1"),
    TvLibraryFilterOption(key = "2", title = "周二", apiValue = "2"),
    TvLibraryFilterOption(key = "3", title = "周三", apiValue = "3"),
    TvLibraryFilterOption(key = "4", title = "周四", apiValue = "4"),
    TvLibraryFilterOption(key = "5", title = "周五", apiValue = "5"),
    TvLibraryFilterOption(key = "6", title = "周六", apiValue = "6"),
    TvLibraryFilterOption(key = "7", title = "周日", apiValue = "7"),
)

/** 电影高级类型选项。 */
private val MOVIE_TYPE_OPTIONS = listOf(
    TvLibraryFilterOption(key = "all", title = "全部", apiValue = "all"),
    TvLibraryFilterOption(key = "comedy", title = "喜剧", apiValue = "comedy"),
    TvLibraryFilterOption(key = "romance", title = "爱情", apiValue = "romance"),
    TvLibraryFilterOption(key = "action", title = "动作", apiValue = "action"),
    TvLibraryFilterOption(key = "sci-fi", title = "科幻", apiValue = "sci-fi"),
    TvLibraryFilterOption(key = "suspense", title = "悬疑", apiValue = "suspense"),
    TvLibraryFilterOption(key = "crime", title = "犯罪", apiValue = "crime"),
    TvLibraryFilterOption(key = "thriller", title = "惊悚", apiValue = "thriller"),
    TvLibraryFilterOption(key = "adventure", title = "冒险", apiValue = "adventure"),
    TvLibraryFilterOption(key = "music", title = "音乐", apiValue = "music"),
    TvLibraryFilterOption(key = "history", title = "历史", apiValue = "history"),
    TvLibraryFilterOption(key = "fantasy", title = "奇幻", apiValue = "fantasy"),
    TvLibraryFilterOption(key = "horror", title = "恐怖", apiValue = "horror"),
    TvLibraryFilterOption(key = "war", title = "战争", apiValue = "war"),
    TvLibraryFilterOption(key = "biography", title = "传记", apiValue = "biography"),
    TvLibraryFilterOption(key = "musical", title = "歌舞", apiValue = "musical"),
    TvLibraryFilterOption(key = "wuxia", title = "武侠", apiValue = "wuxia"),
    TvLibraryFilterOption(key = "erotic", title = "情色", apiValue = "erotic"),
    TvLibraryFilterOption(key = "disaster", title = "灾难", apiValue = "disaster"),
    TvLibraryFilterOption(key = "western", title = "西部", apiValue = "western"),
    TvLibraryFilterOption(key = "documentary", title = "纪录片", apiValue = "documentary"),
    TvLibraryFilterOption(key = "short", title = "短片", apiValue = "short"),
)

/** 剧集高级类型选项。 */
private val SERIES_TYPE_OPTIONS = listOf(
    TvLibraryFilterOption(key = "all", title = "全部", apiValue = "all"),
    TvLibraryFilterOption(key = "comedy", title = "喜剧", apiValue = "comedy"),
    TvLibraryFilterOption(key = "romance", title = "爱情", apiValue = "romance"),
    TvLibraryFilterOption(key = "suspense", title = "悬疑", apiValue = "suspense"),
    TvLibraryFilterOption(key = "wuxia", title = "武侠", apiValue = "wuxia"),
    TvLibraryFilterOption(key = "costume", title = "古装", apiValue = "costume"),
    TvLibraryFilterOption(key = "family", title = "家庭", apiValue = "family"),
    TvLibraryFilterOption(key = "crime", title = "犯罪", apiValue = "crime"),
    TvLibraryFilterOption(key = "sci-fi", title = "科幻", apiValue = "sci-fi"),
    TvLibraryFilterOption(key = "horror", title = "恐怖", apiValue = "horror"),
    TvLibraryFilterOption(key = "history", title = "历史", apiValue = "history"),
    TvLibraryFilterOption(key = "war", title = "战争", apiValue = "war"),
    TvLibraryFilterOption(key = "action", title = "动作", apiValue = "action"),
    TvLibraryFilterOption(key = "adventure", title = "冒险", apiValue = "adventure"),
    TvLibraryFilterOption(key = "biography", title = "传记", apiValue = "biography"),
    TvLibraryFilterOption(key = "drama", title = "剧情", apiValue = "drama"),
    TvLibraryFilterOption(key = "fantasy", title = "奇幻", apiValue = "fantasy"),
    TvLibraryFilterOption(key = "thriller", title = "惊悚", apiValue = "thriller"),
    TvLibraryFilterOption(key = "disaster", title = "灾难", apiValue = "disaster"),
    TvLibraryFilterOption(key = "musical", title = "歌舞", apiValue = "musical"),
    TvLibraryFilterOption(key = "music", title = "音乐", apiValue = "music"),
)

/** 综艺高级类型选项。 */
private val VARIETY_TYPE_OPTIONS = listOf(
    TvLibraryFilterOption(key = "all", title = "全部", apiValue = "all"),
    TvLibraryFilterOption(key = "reality", title = "真人秀", apiValue = "reality"),
    TvLibraryFilterOption(key = "talkshow", title = "脱口秀", apiValue = "talkshow"),
    TvLibraryFilterOption(key = "music", title = "音乐", apiValue = "music"),
    TvLibraryFilterOption(key = "musical", title = "歌舞", apiValue = "musical"),
)

/** 动漫番剧类型选项。 */
private val ANIME_SERIES_TYPE_OPTIONS = listOf(
    TvLibraryFilterOption(key = "all", title = "全部", apiValue = "all"),
    TvLibraryFilterOption(key = "dark_humor", title = "黑色幽默", apiValue = "dark_humor"),
    TvLibraryFilterOption(key = "history", title = "历史", apiValue = "history"),
    TvLibraryFilterOption(key = "musical", title = "歌舞", apiValue = "musical"),
    TvLibraryFilterOption(key = "inspirational", title = "励志", apiValue = "inspirational"),
    TvLibraryFilterOption(key = "parody", title = "恶搞", apiValue = "parody"),
    TvLibraryFilterOption(key = "healing", title = "治愈", apiValue = "healing"),
    TvLibraryFilterOption(key = "sports", title = "运动", apiValue = "sports"),
    TvLibraryFilterOption(key = "harem", title = "后宫", apiValue = "harem"),
    TvLibraryFilterOption(key = "erotic", title = "情色", apiValue = "erotic"),
    TvLibraryFilterOption(key = "chinese_anime", title = "国漫", apiValue = "chinese_anime"),
    TvLibraryFilterOption(key = "human_nature", title = "人性", apiValue = "human_nature"),
    TvLibraryFilterOption(key = "suspense", title = "悬疑", apiValue = "suspense"),
    TvLibraryFilterOption(key = "love", title = "恋爱", apiValue = "love"),
    TvLibraryFilterOption(key = "fantasy", title = "魔幻", apiValue = "fantasy"),
    TvLibraryFilterOption(key = "sci_fi", title = "科幻", apiValue = "sci_fi"),
)

/** 动漫剧场版类型选项。 */
private val ANIME_MOVIE_TYPE_OPTIONS = listOf(
    TvLibraryFilterOption(key = "all", title = "全部", apiValue = "all"),
    TvLibraryFilterOption(key = "stop_motion", title = "定格动画", apiValue = "stop_motion"),
    TvLibraryFilterOption(key = "biography", title = "传记", apiValue = "biography"),
    TvLibraryFilterOption(key = "us_animation", title = "美国动画", apiValue = "us_animation"),
    TvLibraryFilterOption(key = "romance", title = "爱情", apiValue = "romance"),
    TvLibraryFilterOption(key = "dark_humor", title = "黑色幽默", apiValue = "dark_humor"),
    TvLibraryFilterOption(key = "musical", title = "歌舞", apiValue = "musical"),
    TvLibraryFilterOption(key = "children", title = "儿童", apiValue = "children"),
    TvLibraryFilterOption(key = "anime", title = "二次元", apiValue = "anime"),
    TvLibraryFilterOption(key = "animal", title = "动物", apiValue = "animal"),
    TvLibraryFilterOption(key = "youth", title = "青春", apiValue = "youth"),
    TvLibraryFilterOption(key = "history", title = "历史", apiValue = "history"),
    TvLibraryFilterOption(key = "inspirational", title = "励志", apiValue = "inspirational"),
    TvLibraryFilterOption(key = "parody", title = "恶搞", apiValue = "parody"),
    TvLibraryFilterOption(key = "healing", title = "治愈", apiValue = "healing"),
    TvLibraryFilterOption(key = "sports", title = "运动", apiValue = "sports"),
    TvLibraryFilterOption(key = "harem", title = "后宫", apiValue = "harem"),
    TvLibraryFilterOption(key = "erotic", title = "情色", apiValue = "erotic"),
    TvLibraryFilterOption(key = "human_nature", title = "人性", apiValue = "human_nature"),
    TvLibraryFilterOption(key = "suspense", title = "悬疑", apiValue = "suspense"),
    TvLibraryFilterOption(key = "love", title = "恋爱", apiValue = "love"),
    TvLibraryFilterOption(key = "fantasy", title = "魔幻", apiValue = "fantasy"),
    TvLibraryFilterOption(key = "sci_fi", title = "科幻", apiValue = "sci_fi"),
)

/** 通用地区选项。 */
private val REGION_OPTIONS = listOf(
    TvLibraryFilterOption(key = "all", title = "全部", apiValue = "all"),
    TvLibraryFilterOption(key = "chinese", title = "华语", apiValue = "chinese"),
    TvLibraryFilterOption(key = "western", title = "欧美", apiValue = "western"),
    TvLibraryFilterOption(key = "korean", title = "韩国", apiValue = "korean"),
    TvLibraryFilterOption(key = "japanese", title = "日本", apiValue = "japanese"),
    TvLibraryFilterOption(key = "mainland_china", title = "中国大陆", apiValue = "mainland_china"),
    TvLibraryFilterOption(key = "usa", title = "美国", apiValue = "usa"),
    TvLibraryFilterOption(key = "hong_kong", title = "中国香港", apiValue = "hong_kong"),
    TvLibraryFilterOption(key = "taiwan", title = "中国台湾", apiValue = "taiwan"),
    TvLibraryFilterOption(key = "uk", title = "英国", apiValue = "uk"),
    TvLibraryFilterOption(key = "france", title = "法国", apiValue = "france"),
    TvLibraryFilterOption(key = "germany", title = "德国", apiValue = "germany"),
    TvLibraryFilterOption(key = "italy", title = "意大利", apiValue = "italy"),
    TvLibraryFilterOption(key = "spain", title = "西班牙", apiValue = "spain"),
    TvLibraryFilterOption(key = "india", title = "印度", apiValue = "india"),
    TvLibraryFilterOption(key = "thailand", title = "泰国", apiValue = "thailand"),
    TvLibraryFilterOption(key = "russia", title = "俄罗斯", apiValue = "russia"),
    TvLibraryFilterOption(key = "canada", title = "加拿大", apiValue = "canada"),
    TvLibraryFilterOption(key = "australia", title = "澳大利亚", apiValue = "australia"),
    TvLibraryFilterOption(key = "ireland", title = "爱尔兰", apiValue = "ireland"),
    TvLibraryFilterOption(key = "sweden", title = "瑞典", apiValue = "sweden"),
    TvLibraryFilterOption(key = "brazil", title = "巴西", apiValue = "brazil"),
    TvLibraryFilterOption(key = "denmark", title = "丹麦", apiValue = "denmark"),
)

/** 通用年份选项。 */
private val YEAR_OPTIONS = listOf(
    TvLibraryFilterOption(key = "all", title = "全部", apiValue = "all"),
    TvLibraryFilterOption(key = "2020s", title = "2020年代", apiValue = "2020s"),
    TvLibraryFilterOption(key = "2025", title = "2025", apiValue = "2025"),
    TvLibraryFilterOption(key = "2024", title = "2024", apiValue = "2024"),
    TvLibraryFilterOption(key = "2023", title = "2023", apiValue = "2023"),
    TvLibraryFilterOption(key = "2022", title = "2022", apiValue = "2022"),
    TvLibraryFilterOption(key = "2021", title = "2021", apiValue = "2021"),
    TvLibraryFilterOption(key = "2020", title = "2020", apiValue = "2020"),
    TvLibraryFilterOption(key = "2019", title = "2019", apiValue = "2019"),
    TvLibraryFilterOption(key = "2010s", title = "2010年代", apiValue = "2010s"),
    TvLibraryFilterOption(key = "2000s", title = "2000年代", apiValue = "2000s"),
    TvLibraryFilterOption(key = "1990s", title = "90年代", apiValue = "1990s"),
    TvLibraryFilterOption(key = "1980s", title = "80年代", apiValue = "1980s"),
    TvLibraryFilterOption(key = "1970s", title = "70年代", apiValue = "1970s"),
    TvLibraryFilterOption(key = "1960s", title = "60年代", apiValue = "1960s"),
    TvLibraryFilterOption(key = "earlier", title = "更早", apiValue = "earlier"),
)

/** 通用平台选项。 */
private val PLATFORM_OPTIONS = listOf(
    TvLibraryFilterOption(key = "all", title = "全部", apiValue = "all"),
    TvLibraryFilterOption(key = "tencent", title = "腾讯视频", apiValue = "tencent"),
    TvLibraryFilterOption(key = "iqiyi", title = "爱奇艺", apiValue = "iqiyi"),
    TvLibraryFilterOption(key = "youku", title = "优酷", apiValue = "youku"),
    TvLibraryFilterOption(key = "hunan_tv", title = "湖南卫视", apiValue = "hunan_tv"),
    TvLibraryFilterOption(key = "netflix", title = "Netflix", apiValue = "netflix"),
    TvLibraryFilterOption(key = "hbo", title = "HBO", apiValue = "hbo"),
    TvLibraryFilterOption(key = "bbc", title = "BBC", apiValue = "bbc"),
    TvLibraryFilterOption(key = "nhk", title = "NHK", apiValue = "nhk"),
    TvLibraryFilterOption(key = "cbs", title = "CBS", apiValue = "cbs"),
    TvLibraryFilterOption(key = "nbc", title = "NBC", apiValue = "nbc"),
    TvLibraryFilterOption(key = "tvn", title = "tvN", apiValue = "tvn"),
)

/** 电影排序选项。 */
private val MOVIE_SORT_OPTIONS = listOf(
    TvLibraryFilterOption(key = "T", title = "综合排序", apiValue = "T"),
    TvLibraryFilterOption(key = "U", title = "近期热度", apiValue = "U"),
    TvLibraryFilterOption(key = "R", title = "首映时间", apiValue = "R"),
    TvLibraryFilterOption(key = "S", title = "高分优先", apiValue = "S"),
)

/** 剧集排序选项。 */
private val SERIES_SORT_OPTIONS = listOf(
    TvLibraryFilterOption(key = "T", title = "综合排序", apiValue = "T"),
    TvLibraryFilterOption(key = "U", title = "近期热度", apiValue = "U"),
    TvLibraryFilterOption(key = "R", title = "首播时间", apiValue = "R"),
    TvLibraryFilterOption(key = "S", title = "高分优先", apiValue = "S"),
)

/** 综艺排序选项。 */
private val VARIETY_SORT_OPTIONS = listOf(
    TvLibraryFilterOption(key = "T", title = "综合排序", apiValue = "T"),
    TvLibraryFilterOption(key = "U", title = "近期热度", apiValue = "U"),
    TvLibraryFilterOption(key = "R", title = "首播时间", apiValue = "R"),
    TvLibraryFilterOption(key = "S", title = "高分优先", apiValue = "S"),
)

/** 动漫排序选项。 */
private val ANIME_SORT_OPTIONS = listOf(
    TvLibraryFilterOption(key = "T", title = "综合排序", apiValue = "T"),
    TvLibraryFilterOption(key = "U", title = "近期热度", apiValue = "U"),
    TvLibraryFilterOption(key = "R", title = "首映时间", apiValue = "R"),
    TvLibraryFilterOption(key = "S", title = "高分优先", apiValue = "S"),
)

/**
 * 创建分类页筛选行（1:1 对齐 Flutter TV rowsFor 动态逻辑）。
 *
 * @param categoryKey 分类标识。
 * @param selectedOptions 当前已选筛选项（filterKey -> optionKey 映射）。
 * @return 当前分类支持的筛选行。
 */
fun defaultLibraryFiltersFor(
    categoryKey: String,
    selectedOptions: Map<String, String> = emptyMap(),
): List<TvLibraryFilter> {
    return when (categoryKey) {
        "movie" -> movieFilterRows(selectedOptions)
        "tv" -> seriesFilterRows(selectedOptions)
        "anime" -> animeFilterRows(selectedOptions)
        "show" -> varietyFilterRows(selectedOptions)
        else -> movieFilterRows(selectedOptions)
    }
}

/** 从已选映射或默认值中取筛选行当前选项。 */
private fun selectedOrDefault(
    selectedOptions: Map<String, String>,
    filterKey: String,
    default: String,
): String = selectedOptions[filterKey] ?: default

/**
 * 根据已选筛选构建 movie 筛选行（simple vs advanced）。
 */
private fun movieFilterRows(selectedOptions: Map<String, String>): List<TvLibraryFilter> {
    val categoryKey = selectedOrDefault(selectedOptions, "分类", "热门")
    if (categoryKey == "全部") {
        // 高级筛选：展示全部筛选行
        return listOf(
            TvLibraryFilter(key = "分类", title = "分类", options = MOVIE_CLASS_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "分类", "热门")),
            TvLibraryFilter(key = "类型", title = "类型", options = MOVIE_TYPE_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "类型", "all")),
            TvLibraryFilter(key = "地区", title = "地区", options = REGION_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "地区", "all")),
            TvLibraryFilter(key = "年代", title = "年代", options = YEAR_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "年代", "all")),
            TvLibraryFilter(key = "平台", title = "平台", options = PLATFORM_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "平台", "all")),
            TvLibraryFilter(key = "排序", title = "排序", options = MOVIE_SORT_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "排序", "T")),
        )
    }
    // 简单筛选：只有分类 + 地区
    return listOf(
        TvLibraryFilter(key = "分类", title = "分类", options = MOVIE_CLASS_OPTIONS,
            selectedOptionKey = selectedOrDefault(selectedOptions, "分类", "热门")),
        TvLibraryFilter(key = "地区", title = "地区", options = MOVIE_SIMPLE_REGION_OPTIONS,
            selectedOptionKey = selectedOrDefault(selectedOptions, "地区", "全部")),
    )
}

/**
 * 根据已选筛选构建 series 筛选行（simple vs advanced）。
 */
private fun seriesFilterRows(selectedOptions: Map<String, String>): List<TvLibraryFilter> {
    val categoryKey = selectedOrDefault(selectedOptions, "分类", "最近热门")
    if (categoryKey == "全部") {
        return listOf(
            TvLibraryFilter(key = "分类", title = "分类", options = TV_CLASS_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "分类", "最近热门")),
            TvLibraryFilter(key = "类型", title = "类型", options = SERIES_TYPE_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "类型", "all")),
            TvLibraryFilter(key = "地区", title = "地区", options = REGION_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "地区", "all")),
            TvLibraryFilter(key = "年代", title = "年代", options = YEAR_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "年代", "all")),
            TvLibraryFilter(key = "平台", title = "平台", options = PLATFORM_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "平台", "all")),
            TvLibraryFilter(key = "排序", title = "排序", options = SERIES_SORT_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "排序", "T")),
        )
    }
    return listOf(
        TvLibraryFilter(key = "分类", title = "分类", options = TV_CLASS_OPTIONS,
            selectedOptionKey = selectedOrDefault(selectedOptions, "分类", "最近热门")),
        TvLibraryFilter(key = "类型", title = "类型", options = SERIES_SIMPLE_TYPE_OPTIONS,
            selectedOptionKey = selectedOrDefault(selectedOptions, "类型", "tv")),
    )
}

/**
 * 根据已选筛选构建 anime 筛选行（每日放送 / 番剧 / 剧场版）。
 */
private fun animeFilterRows(selectedOptions: Map<String, String>): List<TvLibraryFilter> {
    val categoryKey = selectedOrDefault(selectedOptions, "分类", "每日放送")
    val todayWeekday = java.time.LocalDate.now().dayOfWeek.value.toString()
    return when (categoryKey) {
        "每日放送" -> listOf(
            TvLibraryFilter(key = "分类", title = "分类", options = ANIME_CLASS_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "分类", "每日放送")),
            TvLibraryFilter(key = "星期", title = "星期", options = WEEKDAY_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "星期", todayWeekday)),
        )
        "番剧" -> listOf(
            TvLibraryFilter(key = "分类", title = "分类", options = ANIME_CLASS_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "分类", "每日放送")),
            TvLibraryFilter(key = "类型", title = "类型", options = ANIME_SERIES_TYPE_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "类型", "all")),
            TvLibraryFilter(key = "地区", title = "地区", options = REGION_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "地区", "all")),
            TvLibraryFilter(key = "年代", title = "年代", options = YEAR_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "年代", "all")),
            TvLibraryFilter(key = "平台", title = "平台", options = PLATFORM_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "平台", "all")),
            TvLibraryFilter(key = "排序", title = "排序", options = ANIME_SORT_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "排序", "T")),
        )
        else -> listOf(
            TvLibraryFilter(key = "分类", title = "分类", options = ANIME_CLASS_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "分类", "每日放送")),
            TvLibraryFilter(key = "类型", title = "类型", options = ANIME_MOVIE_TYPE_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "类型", "all")),
            TvLibraryFilter(key = "地区", title = "地区", options = REGION_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "地区", "all")),
            TvLibraryFilter(key = "年代", title = "年代", options = YEAR_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "年代", "all")),
            TvLibraryFilter(key = "排序", title = "排序", options = ANIME_SORT_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "排序", "T")),
        )
    }
}

/**
 * 根据已选筛选构建 variety 筛选行（simple vs advanced）。
 */
private fun varietyFilterRows(selectedOptions: Map<String, String>): List<TvLibraryFilter> {
    val categoryKey = selectedOrDefault(selectedOptions, "分类", "最近热门")
    if (categoryKey == "全部") {
        return listOf(
            TvLibraryFilter(key = "分类", title = "分类", options = SHOW_CLASS_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "分类", "最近热门")),
            TvLibraryFilter(key = "类型", title = "类型", options = VARIETY_TYPE_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "类型", "all")),
            TvLibraryFilter(key = "地区", title = "地区", options = REGION_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "地区", "all")),
            TvLibraryFilter(key = "年代", title = "年代", options = YEAR_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "年代", "all")),
            TvLibraryFilter(key = "平台", title = "平台", options = PLATFORM_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "平台", "all")),
            TvLibraryFilter(key = "排序", title = "排序", options = VARIETY_SORT_OPTIONS,
                selectedOptionKey = selectedOrDefault(selectedOptions, "排序", "T")),
        )
    }
    return listOf(
        TvLibraryFilter(key = "分类", title = "分类", options = SHOW_CLASS_OPTIONS,
            selectedOptionKey = selectedOrDefault(selectedOptions, "分类", "最近热门")),
        TvLibraryFilter(key = "类型", title = "类型", options = VARIETY_SIMPLE_TYPE_OPTIONS,
            selectedOptionKey = selectedOrDefault(selectedOptions, "类型", "show")),
    )
}

/**
 * 将接口返回分区归一化为 Flutter TV 首页顺序。
 *
 * @param onlyReadyKeys 非空时只展示这些已就绪分区，未返回的块不提前补空模板。
 * @return 按固定顺序排列后的分区列表。
 */
private fun List<TvHomeSection>.normalizedForFlutterTvHome(
    onlyReadyKeys: Set<String>? = null,
): List<TvHomeSection> {
    val incomingByKey = associateBy { section -> section.key }
    return HOME_SECTION_TEMPLATES
        .asSequence()
        .filter { template ->
            // 流式加载：未返回的分区先不占位，避免“一股脑”空块。
            onlyReadyKeys == null || template.key in onlyReadyKeys
        }
        .map { template -> incomingByKey[template.key] ?: template }
        .filterNot { section ->
            // 无卡片分区整块隐藏：遥控器下移时不会落到空「新番放送」等轨道上。
            // 继续观看空也隐藏；流式加载中未就绪分区本就不会进入 onlyReadyKeys。
            section.videos.isEmpty()
        }
        .toList()
}

/**
 * 用最新继续观看结果替换首页中的续播分区。
 *
 * @param videos 最新续播视频列表。
 * @return 仅替换续播块后的首页分区。
 */
private fun List<TvHomeSection>.withContinueWatchingVideos(
    videos: List<TvVideoCard>,
): List<TvHomeSection> {
    val continueSection = TvHomeSection(
        key = "continue_watching",
        title = "继续观看",
        videos = videos,
    )
    val sectionsWithoutContinue = filterNot { section -> section.key == "continue_watching" }
    return if (videos.isEmpty()) {
        sectionsWithoutContinue
    } else if (any { section -> section.key == "continue_watching" }) {
        map { section ->
            if (section.key == "continue_watching") {
                continueSection
            } else {
                section
            }
        }
    } else {
        listOf(continueSection) + sectionsWithoutContinue
    }
}

/**
 * 计算视频库网格焦点下标。
 *
 * @param currentIndex 当前焦点下标。
 * @param itemCount 视频总数。
 * @param columns 每行列数。
 * @param direction 移动方向。
 * @return 约束在列表范围内的下一焦点下标。
 */
fun nextLibraryGridFocusIndex(
    currentIndex: Int,
    itemCount: Int,
    columns: Int,
    direction: TvGridFocusDirection,
): Int {
    if (itemCount <= 0) {
        return 0
    }
    val safeColumns = columns.coerceAtLeast(1)
    val safeIndex = currentIndex.coerceIn(0, itemCount - 1)
    return when (direction) {
        TvGridFocusDirection.Left -> (safeIndex - 1).coerceAtLeast(0)
        TvGridFocusDirection.Right -> (safeIndex + 1).coerceAtMost(itemCount - 1)
        TvGridFocusDirection.Up -> (safeIndex - safeColumns).coerceAtLeast(0)
        TvGridFocusDirection.Down -> (safeIndex + safeColumns).coerceAtMost(itemCount - 1)
    }
}
