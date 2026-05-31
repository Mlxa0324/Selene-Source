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
 * @property resultGroups 搜索结果分组。
 * @property isLoading 是否正在搜索。
 */
data class TvSearchUiState(
    val query: String = "",
    val searchHistory: List<String> = emptyList(),
    val hotQueries: List<String> = DEFAULT_HOT_QUERIES,
    val resultGroups: List<TvSearchResultGroup> = emptyList(),
    val isLoading: Boolean = false,
)

/**
 * TV 搜索 ViewModel。
 *
 * @property search 搜索执行函数。
 */
class TvSearchViewModel(
    private val search: suspend (query: String) -> TvSearchPayload,
) {
    /** 搜索内部状态。 */
    private val mutableState = MutableStateFlow(TvSearchUiState())

    /** 搜索公开状态。 */
    val state: StateFlow<TvSearchUiState> = mutableState

    /**
     * 提交搜索关键词。
     *
     * @param query 搜索关键词。
     */
    suspend fun submitQuery(query: String) {
        val normalizedQuery = query.trim()
        if (normalizedQuery.isEmpty()) {
            // 空搜索词不触发接口请求，保持遥控器误确认时状态稳定。
            return
        }

        mutableState.value = mutableState.value.copy(
            query = normalizedQuery,
            isLoading = true,
        )
        val payload = search(normalizedQuery)
        mutableState.value = mutableState.value.copy(
            searchHistory = listOf(normalizedQuery) + mutableState.value.searchHistory.filterNot { it == normalizedQuery },
            resultGroups = listOf(TvSearchResultGroup(title = SEARCH_RESULT_GROUP_TITLE, videos = payload.results)),
            isLoading = false,
        )
    }

    private companion object {
        /** 搜索结果默认分组标题。 */
        const val SEARCH_RESULT_GROUP_TITLE = "搜索结果"
    }
}

/** TV 搜索页默认热词，用于无服务端热词时保持入口可浏览。 */
private val DEFAULT_HOT_QUERIES = listOf("热门电影", "高分剧集", "动漫新番", "综艺更新")
