package org.moontechlab.selene.tv.feature.search

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.SeleneTvSearchStreamClient
import org.moontechlab.selene.tv.core.network.TvSearchCompleteEvent
import org.moontechlab.selene.tv.core.network.TvSearchSourceErrorEvent
import org.moontechlab.selene.tv.core.network.TvSearchSourceResultEvent
import org.moontechlab.selene.tv.core.network.TvSearchStartEvent
import org.moontechlab.selene.tv.core.network.model.TvSearchResultResponse

/**
 * 搜索页右侧面板模式。
 *
 * 对齐 Flutter TV：首页 / 首字母联想 / 搜索结果。
 */
enum class TvSearchPanelMode {
    /** 默认首页：历史 + 热词 + 推荐。 */
    Home,

    /** 纯字母数字输入后的联想面板。 */
    Suggestions,

    /** 真正发起搜索后的结果面板。 */
    Results,
}

/**
 * TV 搜索页 UI 状态。
 *
 * @property query 当前输入词。
 * @property searchHistory 搜索历史。
 * @property hotQueries 搜索热词。
 * @property recommendCards 影片推荐。
 * @property suggestions 首字母联想结果。
 * @property resultCards 聚合后的搜索结果卡片。
 * @property panelMode 右侧面板模式。
 * @property isBootstrapping 首屏历史/推荐是否加载中。
 * @property isSuggestionLoading 联想是否加载中。
 * @property isSearchResultLoading 搜索结果是否加载中。
 * @property searchCompletedResourceCount 已完成资源站数。
 * @property searchTotalResourceCount 资源站总数。
 * @property errorMessage 搜索失败文案。
 * @property bootstrapErrorMessage 首屏加载失败文案。
 */
data class TvSearchUiState(
    val query: String = "",
    val searchHistory: List<String> = emptyList(),
    val hotQueries: List<String> = emptyList(),
    val recommendCards: List<TvVideoCard> = emptyList(),
    val suggestions: List<String> = emptyList(),
    val resultCards: List<TvVideoCard> = emptyList(),
    val panelMode: TvSearchPanelMode = TvSearchPanelMode.Home,
    val isBootstrapping: Boolean = false,
    val isSuggestionLoading: Boolean = false,
    val isSearchResultLoading: Boolean = false,
    val searchCompletedResourceCount: Int = 0,
    val searchTotalResourceCount: Int = 0,
    val errorMessage: String? = null,
    val bootstrapErrorMessage: String? = null,
) {
    /**
     * 是否展示搜索结果面板。
     */
    val showResultsPanel: Boolean
        get() = panelMode == TvSearchPanelMode.Results

    /**
     * 是否展示联想面板。
     */
    val showSuggestionPanel: Boolean
        get() = panelMode == TvSearchPanelMode.Suggestions

    /**
     * 是否展示首页面板。
     */
    val showHomePanel: Boolean
        get() = panelMode == TvSearchPanelMode.Home
}

/**
 * TV 搜索页 ViewModel。
 *
 * 对齐 Flutter `TvSearchScreen` 的状态机：
 * - 键盘输入字母数字 → 联想
 * - 历史/确认搜索 → SSE 流式结果并按片名聚合
 * - 热词 → 仅回填输入框
 * - 返回键优先退出结果/联想，再退出页面
 *
 * @property loadBootstrap 加载历史、热词、推荐。
 * @property loadSuggestions 加载首字母联想。
 * @property searchStream 流式搜索客户端；为空时回退批搜索。
 * @property batchSearch 批搜索兜底。
 * @property clearSearchHistory 清空远端搜索历史。
 * @property saveSearchHistory 本地/远端写入历史（可选）。
 * @property backgroundScope 后台协程作用域。
 */
class TvSearchViewModel(
    private val loadBootstrap: suspend () -> TvSearchBootstrapData = {
        TvSearchBootstrapData()
    },
    private val loadSuggestions: suspend (String) -> List<String> = { emptyList() },
    private val searchStream: SeleneTvSearchStreamClient? = null,
    private val batchSearch: suspend (String) -> List<TvVideoCard> = { emptyList() },
    private val clearSearchHistory: suspend () -> Boolean = { true },
    private val saveSearchHistory: suspend (List<String>) -> Unit = {},
    private val backgroundScope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
) {
    /** 搜索内部状态。 */
    private val mutableState = MutableStateFlow(TvSearchUiState())

    /** 搜索公开状态。 */
    val state: StateFlow<TvSearchUiState> = mutableState

    /** 联想请求版本号，用于丢弃过期回包。 */
    private var suggestionRequestVersion: Int = 0

    /** 搜索请求版本号，用于丢弃过期 SSE 回包。 */
    private var searchRequestVersion: Int = 0

    /** 联想加载任务。 */
    private var suggestionJob: Job? = null

    /** 搜索加载任务。 */
    private var searchJob: Job? = null

    /** 进入搜索结果前的联想输入快照，返回时可恢复。 */
    private var suggestionQueryBeforeSearch: String? = null

    /** 进入搜索结果前的联想列表快照。 */
    private var suggestionsBeforeSearch: List<String> = emptyList()

    /** 原始 SSE 搜索结果，供同片名聚合。 */
    private val rawSearchResults = mutableListOf<TvSearchResultResponse>()

    /**
     * 加载搜索页首屏数据。
     */
    fun bootstrap() {
        if (mutableState.value.isBootstrapping) {
            return
        }
        mutableState.value = mutableState.value.copy(
            isBootstrapping = true,
            bootstrapErrorMessage = null,
        )
        backgroundScope.launch {
            runCatching { loadBootstrap() }
                .onSuccess { data ->
                    mutableState.value = mutableState.value.copy(
                        searchHistory = data.searchHistory.take(MAX_HISTORY_COUNT),
                        hotQueries = data.hotQueries,
                        recommendCards = data.recommendCards,
                        isBootstrapping = false,
                        bootstrapErrorMessage = null,
                    )
                }
                .onFailure { throwable ->
                    mutableState.value = mutableState.value.copy(
                        isBootstrapping = false,
                        bootstrapErrorMessage = throwable.message ?: "搜索页加载失败",
                    )
                }
        }
    }

    /**
     * 兼容旧接口：只刷新历史。
     */
    suspend fun loadHistory() {
        bootstrap()
    }

    /**
     * 键盘追加字符。
     *
     * @param char 追加字符。
     */
    fun appendChar(char: String) {
        val current = mutableState.value.query
        if (current.length >= MAX_QUERY_LENGTH) {
            return
        }
        updateQuery(
            nextQuery = current + char,
            preserveSuggestionContext = current.isNotEmpty() && canRestoreSuggestionPanel(),
        )
    }

    /**
     * 删除最后一个字符。
     */
    fun deleteLastChar() {
        val current = mutableState.value.query
        if (current.isEmpty()) {
            return
        }
        updateQuery(
            nextQuery = current.dropLast(1),
            preserveSuggestionContext = canRestoreSuggestionPanel(),
        )
    }

    /**
     * 清空输入。
     */
    fun clearQuery() {
        updateQuery(nextQuery = "", preserveSuggestionContext = false)
    }

    /**
     * 热词回填输入框，不直接搜索。
     *
     * @param query 热词。
     */
    fun setQuery(query: String) {
        updateQuery(nextQuery = query.trim(), preserveSuggestionContext = false)
    }

    /**
     * 点击搜索历史：直接进入结果。
     *
     * @param query 历史词。
     */
    fun submitHistoryQuery(query: String) {
        backgroundScope.launch {
            performSearch(
                query = query,
                preserveSuggestionContext = false,
            )
        }
    }

    /**
     * 点击联想词：保留联想上下文后搜索。
     *
     * @param query 联想词。
     */
    fun submitSuggestionQuery(query: String) {
        backgroundScope.launch {
            performSearch(
                query = query,
                preserveSuggestionContext = true,
            )
        }
    }

    /**
     * 提交当前输入框搜索。
     */
    fun submitCurrentQuery() {
        val current = mutableState.value
        backgroundScope.launch {
            performSearch(
                query = current.query,
                preserveSuggestionContext = current.showSuggestionPanel || canRestoreSuggestionPanel(),
            )
        }
    }

    /**
     * 兼容旧接口：提交指定搜索词。
     *
     * @param query 搜索词。
     */
    suspend fun submitQuery(query: String) {
        performSearch(
            query = query,
            preserveSuggestionContext = false,
        )
    }

    /**
     * 清空搜索历史。
     */
    fun clearHistory() {
        backgroundScope.launch {
            val cleared = runCatching { clearSearchHistory() }.getOrDefault(false)
            if (!cleared) {
                return@launch
            }
            mutableState.value = mutableState.value.copy(searchHistory = emptyList())
        }
    }

    /**
     * 处理返回键。
     *
     * @return true 表示已在搜索页内消费返回；false 表示应退出页面。
     */
    fun handleBack(): Boolean {
        val current = mutableState.value
        if (current.showResultsPanel && canRestoreSuggestionPanel()) {
            restoreSuggestionPanel()
            return true
        }
        if (current.query.isNotEmpty() ||
            current.suggestions.isNotEmpty() ||
            current.resultCards.isNotEmpty() ||
            current.isSearchResultLoading ||
            current.showSuggestionPanel ||
            current.showResultsPanel
        ) {
            resetToSearchHome()
            return true
        }
        return false
    }

    /**
     * 更新输入词并驱动面板模式。
     *
     * @param nextQuery 新输入词。
     * @param preserveSuggestionContext 是否保留结果页返回用的联想快照。
     */
    private fun updateQuery(
        nextQuery: String,
        preserveSuggestionContext: Boolean,
    ) {
        // 键盘字母本身已是大写；中文热词/历史词保持原样，避免误伤片名。
        val normalized = if (nextQuery.matches(Regex("^[A-Za-z0-9]*$"))) {
            nextQuery.uppercase()
        } else {
            nextQuery
        }
        invalidateSearchRequests(preserveSuggestionContext = preserveSuggestionContext)
        invalidateActiveSearch()
        rawSearchResults.clear()
        val shouldSuggest = shouldShowSuggestionPanel(normalized)
        mutableState.value = mutableState.value.copy(
            query = normalized,
            suggestions = if (shouldSuggest) mutableState.value.suggestions else emptyList(),
            resultCards = emptyList(),
            panelMode = when {
                shouldSuggest -> TvSearchPanelMode.Suggestions
                else -> TvSearchPanelMode.Home
            },
            isSuggestionLoading = shouldSuggest,
            isSearchResultLoading = false,
            searchCompletedResourceCount = 0,
            searchTotalResourceCount = 0,
            errorMessage = null,
        )
        if (shouldSuggest) {
            scheduleSuggestions(normalized)
        } else {
            suggestionJob?.cancel()
            mutableState.value = mutableState.value.copy(
                isSuggestionLoading = false,
                suggestions = emptyList(),
            )
        }
    }

    /**
     * 执行搜索。
     *
     * @param query 搜索关键词。
     * @param preserveSuggestionContext 是否保留联想上下文。
     */
    private suspend fun performSearch(
        query: String,
        preserveSuggestionContext: Boolean,
    ) {
        val normalizedQuery = query.trim()
        if (normalizedQuery.isEmpty()) {
            return
        }

        // 进入结果页前快照当前联想态，方便返回继续选词。
        if (preserveSuggestionContext && suggestionQueryBeforeSearch == null) {
            suggestionQueryBeforeSearch = mutableState.value.query
            suggestionsBeforeSearch = mutableState.value.suggestions
        } else if (!preserveSuggestionContext) {
            clearSuggestionSearchContext()
        }

        val requestVersion = ++searchRequestVersion
        suggestionJob?.cancel()
        searchJob?.cancel()
        rawSearchResults.clear()
        mutableState.value = mutableState.value.copy(
            query = normalizedQuery,
            panelMode = TvSearchPanelMode.Results,
            resultCards = emptyList(),
            isSuggestionLoading = false,
            isSearchResultLoading = true,
            searchCompletedResourceCount = 0,
            searchTotalResourceCount = 0,
            errorMessage = null,
        )
        persistHistory(normalizedQuery)

        searchJob = backgroundScope.launch {
            val streamClient = searchStream
            if (streamClient != null) {
                runCatching {
                    streamClient.search(normalizedQuery) { event ->
                        if (requestVersion != searchRequestVersion) {
                            return@search
                        }
                        when (event) {
                            is TvSearchStartEvent -> {
                                mutableState.value = mutableState.value.copy(
                                    searchTotalResourceCount = event.totalSources,
                                    searchCompletedResourceCount = 0,
                                )
                            }

                            is TvSearchSourceResultEvent -> {
                                // 每个源返回一批结果后立刻聚合刷新，对齐 Flutter 边搜边展示。
                                rawSearchResults += event.results
                                val completed = (mutableState.value.searchCompletedResourceCount + 1)
                                    .coerceAtMost(
                                        mutableState.value.searchTotalResourceCount
                                            .takeIf { it > 0 }
                                            ?: Int.MAX_VALUE,
                                    )
                                mutableState.value = mutableState.value.copy(
                                    resultCards = aggregateSearchResults(rawSearchResults),
                                    searchCompletedResourceCount = completed,
                                    isSearchResultLoading = true,
                                    errorMessage = null,
                                )
                            }

                            is TvSearchSourceErrorEvent -> {
                                // 源失败也算完成一个站，进度继续推进。
                                val completed = (mutableState.value.searchCompletedResourceCount + 1)
                                    .coerceAtMost(
                                        mutableState.value.searchTotalResourceCount
                                            .takeIf { it > 0 }
                                            ?: Int.MAX_VALUE,
                                    )
                                mutableState.value = mutableState.value.copy(
                                    searchCompletedResourceCount = completed,
                                )
                            }

                            is TvSearchCompleteEvent -> {
                                mutableState.value = mutableState.value.copy(
                                    resultCards = aggregateSearchResults(rawSearchResults),
                                    searchCompletedResourceCount = event.completedSources,
                                    searchTotalResourceCount = event.completedSources
                                        .coerceAtLeast(mutableState.value.searchTotalResourceCount),
                                    isSearchResultLoading = false,
                                    errorMessage = null,
                                )
                            }
                        }
                    }
                }.onFailure { throwable ->
                    if (requestVersion != searchRequestVersion) {
                        return@launch
                    }
                    // SSE 失败时回退批搜索，保证仍有结果可看。
                    runCatching { batchSearch(normalizedQuery) }
                        .onSuccess { cards ->
                            mutableState.value = mutableState.value.copy(
                                resultCards = cards,
                                isSearchResultLoading = false,
                                errorMessage = null,
                            )
                        }
                        .onFailure {
                            mutableState.value = mutableState.value.copy(
                                isSearchResultLoading = false,
                                errorMessage = throwable.message ?: "搜索失败",
                            )
                        }
                }
            } else {
                runCatching { batchSearch(normalizedQuery) }
                    .onSuccess { cards ->
                        if (requestVersion != searchRequestVersion) {
                            return@launch
                        }
                        mutableState.value = mutableState.value.copy(
                            resultCards = cards,
                            isSearchResultLoading = false,
                            errorMessage = null,
                        )
                    }
                    .onFailure { throwable ->
                        if (requestVersion != searchRequestVersion) {
                            return@launch
                        }
                        mutableState.value = mutableState.value.copy(
                            isSearchResultLoading = false,
                            errorMessage = throwable.message ?: "搜索失败",
                        )
                    }
            }

            if (requestVersion == searchRequestVersion) {
                mutableState.value = mutableState.value.copy(isSearchResultLoading = false)
            }
        }
    }

    /**
     * 调度联想请求。
     *
     * @param query 当前纯字母数字输入。
     */
    private fun scheduleSuggestions(query: String) {
        val requestVersion = ++suggestionRequestVersion
        suggestionJob?.cancel()
        suggestionJob = backgroundScope.launch {
            // 轻微防抖，避免每个按键都立刻打联想接口。
            delay(SUGGESTION_DEBOUNCE_MS)
            if (requestVersion != suggestionRequestVersion) {
                return@launch
            }
            mutableState.value = mutableState.value.copy(isSuggestionLoading = true)
            val suggestions = runCatching { loadSuggestions(query) }
                .getOrDefault(emptyList())
                .let(::dedupeSuggestions)
            if (requestVersion != suggestionRequestVersion) {
                return@launch
            }
            mutableState.value = mutableState.value.copy(
                suggestions = suggestions,
                isSuggestionLoading = false,
                panelMode = TvSearchPanelMode.Suggestions,
            )
        }
    }

    /**
     * 把关键词写入历史列表头部并去重。
     *
     * @param query 搜索词。
     */
    private suspend fun persistHistory(query: String) {
        val nextHistory = (listOf(query) + mutableState.value.searchHistory.filterNot { it == query })
            .take(MAX_HISTORY_COUNT)
        mutableState.value = mutableState.value.copy(searchHistory = nextHistory)
        runCatching { saveSearchHistory(nextHistory) }
    }

    /**
     * 失效搜索请求版本。
     *
     * @param preserveSuggestionContext 是否保留联想返回上下文。
     */
    private fun invalidateSearchRequests(preserveSuggestionContext: Boolean) {
        suggestionRequestVersion += 1
        searchRequestVersion += 1
        if (!preserveSuggestionContext) {
            clearSuggestionSearchContext()
        }
    }

    /**
     * 取消当前搜索任务。
     */
    private fun invalidateActiveSearch() {
        searchJob?.cancel()
        searchJob = null
    }

    /**
     * 清空联想返回上下文。
     */
    private fun clearSuggestionSearchContext() {
        suggestionQueryBeforeSearch = null
        suggestionsBeforeSearch = emptyList()
    }

    /**
     * 是否可从结果页恢复联想面板。
     */
    private fun canRestoreSuggestionPanel(): Boolean {
        return suggestionQueryBeforeSearch != null
    }

    /**
     * 恢复结果页之前的联想面板。
     */
    private fun restoreSuggestionPanel() {
        val suggestionQuery = suggestionQueryBeforeSearch ?: return
        val suggestionSnapshot = suggestionsBeforeSearch
        invalidateActiveSearch()
        rawSearchResults.clear()
        mutableState.value = mutableState.value.copy(
            query = suggestionQuery,
            suggestions = suggestionSnapshot,
            resultCards = emptyList(),
            panelMode = TvSearchPanelMode.Suggestions,
            isSearchResultLoading = false,
            isSuggestionLoading = false,
            searchCompletedResourceCount = 0,
            searchTotalResourceCount = 0,
            errorMessage = null,
        )
    }

    /**
     * 重置到搜索首页。
     */
    private fun resetToSearchHome() {
        invalidateSearchRequests(preserveSuggestionContext = false)
        invalidateActiveSearch()
        suggestionJob?.cancel()
        rawSearchResults.clear()
        mutableState.value = mutableState.value.copy(
            query = "",
            suggestions = emptyList(),
            resultCards = emptyList(),
            panelMode = TvSearchPanelMode.Home,
            isSuggestionLoading = false,
            isSearchResultLoading = false,
            searchCompletedResourceCount = 0,
            searchTotalResourceCount = 0,
            errorMessage = null,
        )
    }

    private companion object {
        /** 搜索词最大长度。 */
        const val MAX_QUERY_LENGTH = 20

        /** 历史最多保留条数，对齐 Flutter take(12)。 */
        const val MAX_HISTORY_COUNT = 12

        /** 联想防抖。 */
        const val SUGGESTION_DEBOUNCE_MS = 180L
    }
}

/**
 * 搜索页首屏数据。
 *
 * @property searchHistory 搜索历史。
 * @property hotQueries 搜索热词。
 * @property recommendCards 推荐卡片。
 */
data class TvSearchBootstrapData(
    val searchHistory: List<String> = emptyList(),
    val hotQueries: List<String> = emptyList(),
    val recommendCards: List<TvVideoCard> = emptyList(),
)

/**
 * 是否应进入首字母联想面板。
 *
 * 对齐 Flutter：仅纯大写字母数字输入触发。
 *
 * @param query 当前输入。
 * @return true 表示进入联想。
 */
internal fun shouldShowSuggestionPanel(query: String): Boolean {
    if (query.isEmpty()) {
        return false
    }
    return query.matches(Regex("^[A-Z0-9]+$"))
}

/**
 * 联想结果去重。
 *
 * @param suggestions 原始联想。
 * @return 去重后列表。
 */
internal fun dedupeSuggestions(suggestions: List<String>): List<String> {
    val ordered = ArrayList<String>()
    val seen = LinkedHashSet<String>()
    for (item in suggestions) {
        val normalized = item.replace(Regex("\\s+"), " ").trim()
        if (normalized.isEmpty() || !seen.add(normalized.lowercase())) {
            continue
        }
        ordered += normalized
    }
    return ordered
}

/**
 * 按片名聚合 SSE 原始搜索结果。
 *
 * 对齐 Flutter `_aggregateSearchResults`：同片名多源只展示一张卡片。
 *
 * @param results 原始结果。
 * @return 聚合后的卡片。
 */
internal fun aggregateSearchResults(results: List<TvSearchResultResponse>): List<TvVideoCard> {
    val grouped = LinkedHashMap<String, MutableList<TvSearchResultResponse>>()
    for (result in results) {
        val titleKey = normalizeSearchTitle(result.title.orEmpty())
        if (titleKey.isEmpty()) {
            continue
        }
        grouped.getOrPut(titleKey) { mutableListOf() }.add(result)
    }
    return grouped.values.map { group -> buildAggregatedVideoCard(group) }
}

/**
 * 规范化搜索片名。
 *
 * @param title 原始标题。
 * @return 折叠空白并小写后的标题。
 */
internal fun normalizeSearchTitle(title: String): String {
    return title.replace(Regex("\\s+"), "").trim().lowercase()
}

/**
 * 将同片名结果聚合为展示卡片。
 *
 * @param results 同片名结果。
 * @return 代表卡片。
 */
private fun buildAggregatedVideoCard(results: List<TvSearchResultResponse>): TvVideoCard {
    val representative = results.maxByOrNull { result ->
        val episodeScore = result.episodes.orEmpty().size * 10
        val posterScore = if (result.poster.orEmpty().isNotBlank()) 1 else 0
        episodeScore + posterScore
    } ?: results.first()
    val maxEpisodeCount = results.maxOfOrNull { it.episodes.orEmpty().size } ?: 0
    val sourceName = results
        .mapNotNull { it.sourceName?.trim()?.takeIf(String::isNotEmpty) }
        .distinct()
        .joinToString(separator = " / ")
        .ifBlank { representative.sourceName.orEmpty() }
    return TvVideoCard(
        id = representative.id.orEmpty(),
        source = representative.source.orEmpty().ifBlank { "aggregated" },
        title = representative.title.orEmpty(),
        sourceName = sourceName,
        year = representative.year.orEmpty(),
        posterUrl = representative.poster.orEmpty(),
        totalEpisodes = maxEpisodeCount,
        searchTitle = representative.title.orEmpty(),
    )
}
