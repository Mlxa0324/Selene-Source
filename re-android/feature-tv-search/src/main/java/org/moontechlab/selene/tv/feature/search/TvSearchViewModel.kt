package org.moontechlab.selene.tv.feature.search

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.moontechlab.selene.tv.core.data.model.TvSearchPayload
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * TV 搜索结果分组。
 *
 * @property title 分组标题。
 * @property videos 分组视频列表。
 */
data class TvSearchResultGroup(
    val title: String,
    val videos: List<TvVideoCard>,
)

/**
 * TV 搜索界面状态。
 *
 * @property query 当前搜索词。
 * @property searchHistory 搜索历史。
 * @property hotQueries 搜索热词。
 * @property resultGroups 搜索结果分组。
 * @property showResults 是否展示搜索结果（查询为空时隐藏）。
 * @property isLoading 是否正在搜索。
 * @property errorMessage 搜索失败文案。
 */
data class TvSearchUiState(
    val query: String = "",
    val searchHistory: List<String> = emptyList(),
    val hotQueries: List<String> = DEFAULT_HOT_QUERIES,
    val resultGroups: List<TvSearchResultGroup> = emptyList(),
    val showResults: Boolean = false,
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

/**
 * TV 搜索 ViewModel。
 *
 * @property search 搜索执行函数。
 * @property loadSearchHistory 搜索历史加载函数。
 */
class TvSearchViewModel(
    private val search: suspend (query: String) -> TvSearchPayload,
    private val loadSearchHistory: suspend () -> List<String> = { emptyList() },
) {
    /** 搜索内部状态。 */
    private val mutableState = MutableStateFlow(TvSearchUiState())

    /** 搜索公开状态。 */
    val state: StateFlow<TvSearchUiState> = mutableState

    /**
     * 加载搜索历史。
     */
    suspend fun loadHistory() {
        runCatching { loadSearchHistory() }
            .onSuccess { history ->
                mutableState.value = mutableState.value.copy(searchHistory = history)
            }
    }

    /**
     * 键盘追加一个字符到搜索词末尾。
     *
     * @param char 追加字符 (A-Z, 0-9)。
     */
    fun appendChar(char: String) {
        val current = mutableState.value.query
        if (current.length >= MAX_QUERY_LENGTH) return
        mutableState.value = mutableState.value.copy(
            query = current + char,
            showResults = false,
            resultGroups = emptyList(),
            errorMessage = null,
        )
    }

    /**
     * 删除搜索词最后一个字符。
     */
    fun deleteLastChar() {
        val current = mutableState.value.query
        if (current.isEmpty()) return
        mutableState.value = mutableState.value.copy(
            query = current.dropLast(1),
            showResults = false,
            resultGroups = emptyList(),
            errorMessage = null,
        )
    }

    /**
     * 清空搜索词。
     */
    fun clearQuery() {
        mutableState.value = mutableState.value.copy(
            query = "",
            showResults = false,
            resultGroups = emptyList(),
            errorMessage = null,
        )
    }

    /**
     * 直接设置搜索词（来自历史/热词点击），不触发搜索。
     *
     * @param query 要设置的搜索词。
     */
    fun setQuery(query: String) {
        mutableState.value = mutableState.value.copy(
            query = query.trim(),
            showResults = false,
            resultGroups = emptyList(),
            errorMessage = null,
        )
    }

    /**
     * 提交搜索关键词。
     *
     * @param query 搜索关键词。
     */
    suspend fun submitQuery(query: String) {
        val normalizedQuery = query.trim()
        if (normalizedQuery.isEmpty()) return

        mutableState.value = mutableState.value.copy(
            query = normalizedQuery,
            showResults = true,
            isLoading = true,
            errorMessage = null,
        )
        runCatching { search(normalizedQuery) }
            .onSuccess { payload ->
                mutableState.value = mutableState.value.copy(
                    searchHistory = listOf(normalizedQuery) +
                        mutableState.value.searchHistory.filterNot { it == normalizedQuery },
                    resultGroups = listOf(
                        TvSearchResultGroup(
                            title = SEARCH_RESULT_GROUP_TITLE,
                            videos = payload.results,
                        ),
                    ),
                    isLoading = false,
                    errorMessage = null,
                )
            }
            .onFailure { throwable ->
                mutableState.value = mutableState.value.copy(
                    isLoading = false,
                    errorMessage = throwable.message ?: "搜索失败",
                )
            }
    }

    private companion object {
        /** 搜索结果默认分组标题。 */
        const val SEARCH_RESULT_GROUP_TITLE = "搜索结果"

        /** 搜索词最大长度。 */
        const val MAX_QUERY_LENGTH = 32
    }
}

/** TV 搜索页默认热词，用于无服务端热词时保持入口可浏览。 */
private val DEFAULT_HOT_QUERIES = listOf("热门电影", "高分剧集", "动漫新番", "综艺更新")
