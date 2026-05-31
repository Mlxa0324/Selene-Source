package org.moontechlab.selene.tv.feature.home

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
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
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

/**
 * TV 视频库筛选选项。
 *
 * @property key 筛选选项标识。
 * @property title 筛选选项标题。
 */
data class TvLibraryFilterOption(
    val key: String,
    val title: String,
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
 * @property loadHome 首页数据加载函数。
 */
class TvHomeViewModel(
    private val loadHome: suspend () -> TvHomePayload,
) {
    /** 首页内部状态。 */
    private val mutableState = MutableStateFlow(TvHomeUiState())

    /** 首页公开状态。 */
    val state: StateFlow<TvHomeUiState> = mutableState

    /**
     * 加载首页数据。
     */
    suspend fun load() {
        // 加载过程只更新数据状态，不改变当前主菜单选中项。
        mutableState.value = mutableState.value.copy(
            isLoading = true,
            errorMessage = null,
        )
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
}

/**
 * TV 分类视频库 ViewModel。
 *
 * @property categoryKey 分类标识。
 * @property loadCategory 分类数据加载函数。
 */
class TvVideoLibraryViewModel(
    categoryKey: String,
    private val loadCategory: suspend (categoryKey: String) -> TvVideoLibraryUiState,
) {
    /** 分类内部状态。 */
    private val mutableState = MutableStateFlow(TvVideoLibraryUiState.forCategory(categoryKey))

    /** 分类公开状态。 */
    val state: StateFlow<TvVideoLibraryUiState> = mutableState

    /**
     * 加载分类数据。
     */
    suspend fun load() {
        val categoryKey = mutableState.value.categoryKey
        mutableState.value = mutableState.value.copy(
            isLoading = true,
            errorMessage = null,
        )
        runCatching { loadCategory(categoryKey) }
            .onSuccess { payload ->
                mutableState.value = payload.copy(
                    isLoading = false,
                    errorMessage = null,
                )
            }
            .onFailure { throwable ->
                // 分类接口失败必须展示错误态，避免误判为空分类。
                mutableState.value = TvVideoLibraryUiState.forCategory(categoryKey).copy(
                    isLoading = false,
                    errorMessage = throwable.message ?: "分类内容加载失败",
                )
            }
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
    TvHomeSection(key = "history", title = "播放历史", videos = emptyList()),
    TvHomeSection(key = "favorites", title = "收藏夹", videos = emptyList()),
)

/**
 * 通用地区筛选项。
 */
private val COMMON_AREA_OPTIONS = listOf(
    TvLibraryFilterOption(key = "all", title = "全部"),
    TvLibraryFilterOption(key = "cn", title = "华语"),
    TvLibraryFilterOption(key = "us", title = "欧美"),
    TvLibraryFilterOption(key = "kr", title = "韩国"),
    TvLibraryFilterOption(key = "jp", title = "日本"),
)

/**
 * 通用年份筛选项。
 */
private val COMMON_YEAR_OPTIONS = listOf(
    TvLibraryFilterOption(key = "all", title = "全部"),
    TvLibraryFilterOption(key = "2026", title = "2026"),
    TvLibraryFilterOption(key = "2025", title = "2025"),
    TvLibraryFilterOption(key = "2024", title = "2024"),
    TvLibraryFilterOption(key = "2020s", title = "近五年"),
)

/**
 * 通用排序筛选项。
 */
private val COMMON_SORT_OPTIONS = listOf(
    TvLibraryFilterOption(key = "hot", title = "热度"),
    TvLibraryFilterOption(key = "new", title = "最新"),
    TvLibraryFilterOption(key = "score", title = "评分"),
)

/**
 * 将接口返回分区归一化为 Flutter TV 首页顺序。
 *
 * @return 补齐缺失分区后的列表。
 */
private fun List<TvHomeSection>.normalizedForFlutterTvHome(): List<TvHomeSection> {
    val incomingByKey = associateBy { section -> section.key }
    return HOME_SECTION_TEMPLATES.map { template ->
        incomingByKey[template.key] ?: template
    }
}

/**
 * 创建分类页筛选行。
 *
 * @param categoryKey 分类标识。
 * @return 当前分类支持的筛选行。
 */
private fun defaultLibraryFiltersFor(categoryKey: String): List<TvLibraryFilter> {
    return listOf(
        TvLibraryFilter(
            key = "class",
            title = "分类",
            options = classOptionsFor(categoryKey),
        ),
        TvLibraryFilter(
            key = "area",
            title = "地区",
            options = COMMON_AREA_OPTIONS,
        ),
        TvLibraryFilter(
            key = "year",
            title = "年份",
            options = COMMON_YEAR_OPTIONS,
        ),
        TvLibraryFilter(
            key = "sort",
            title = "排序",
            options = COMMON_SORT_OPTIONS,
        ),
    )
}

/**
 * 获取当前分类的类型筛选项。
 *
 * @param categoryKey 分类标识。
 * @return 类型筛选选项。
 */
private fun classOptionsFor(categoryKey: String): List<TvLibraryFilterOption> {
    return when (categoryKey) {
        "movie" -> listOf(
            TvLibraryFilterOption(key = "hot", title = "热门电影"),
            TvLibraryFilterOption(key = "new", title = "最新电影"),
            TvLibraryFilterOption(key = "douban", title = "豆瓣高分"),
        )
        "tv" -> listOf(
            TvLibraryFilterOption(key = "hot", title = "最近热门"),
            TvLibraryFilterOption(key = "domestic", title = "国产剧"),
            TvLibraryFilterOption(key = "oversea", title = "海外剧"),
        )
        "anime" -> listOf(
            TvLibraryFilterOption(key = "calendar", title = "每日放送"),
            TvLibraryFilterOption(key = "series", title = "番剧"),
            TvLibraryFilterOption(key = "movie", title = "剧场版"),
        )
        "show" -> listOf(
            TvLibraryFilterOption(key = "hot", title = "最近热门"),
            TvLibraryFilterOption(key = "mainland", title = "内地综艺"),
            TvLibraryFilterOption(key = "oversea", title = "海外综艺"),
        )
        else -> listOf(TvLibraryFilterOption(key = "all", title = "全部"))
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
