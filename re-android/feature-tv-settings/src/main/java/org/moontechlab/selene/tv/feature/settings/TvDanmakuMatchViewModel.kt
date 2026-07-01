package org.moontechlab.selene.tv.feature.settings

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * TV 弹幕搜索结果。
 *
 * @property success 搜索是否成功。
 * @property errorMessage 搜索失败文案。
 * @property animes 动画候选列表。
 */
data class TvDanmakuSearchResult(
    val success: Boolean,
    val errorMessage: String,
    val animes: List<TvDanmakuSearchAnime>,
)

/**
 * TV 弹幕动画候选。
 *
 * @property animeId 动画 ID。
 * @property animeTitle 动画标题。
 * @property type 类型编码。
 * @property typeDescription 类型描述。
 * @property year 年份。
 * @property episodes 剧集候选列表。
 */
data class TvDanmakuSearchAnime(
    val animeId: Int,
    val animeTitle: String,
    val type: String,
    val typeDescription: String,
    val year: Int,
    val episodes: List<TvDanmakuSearchEpisode>,
)

/**
 * TV 弹幕剧集候选。
 *
 * @property episodeId 弹幕剧集 ID。
 * @property episodeTitle 剧集标题。
 */
data class TvDanmakuSearchEpisode(
    val episodeId: Int,
    val episodeTitle: String,
)

/**
 * TV 弹幕手动匹配界面状态。
 *
 * @property initialQuery 初始搜索词。
 * @property query 当前搜索词。
 * @property results 当前搜索结果。
 * @property isLoading 是否正在搜索。
 * @property errorMessage 错误或空态文案。
 */
data class TvDanmakuMatchUiState(
    val initialQuery: String = "",
    val query: String = "",
    val results: List<TvDanmakuSearchAnime> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null,
)

/**
 * TV 弹幕手动匹配 ViewModel。
 *
 * @param initialQuery 初始搜索词。
 * @param searchEpisodes 弹幕剧集搜索函数。
 */
class TvDanmakuMatchViewModel(
    initialQuery: String,
    private val searchEpisodes: suspend (String) -> TvDanmakuSearchResult? = { null },
) {
    /** 弹幕匹配内部状态。 */
    private val mutableState = MutableStateFlow(
        TvDanmakuMatchUiState(
            initialQuery = initialQuery.trim(),
            query = initialQuery.trim(),
        ),
    )

    /** 弹幕匹配公开状态。 */
    val state: StateFlow<TvDanmakuMatchUiState> = mutableState

    /**
     * 删除当前搜索词最后一个字符。
     */
    fun deleteLastCharacter() {
        val current = mutableState.value.query
        if (current.isEmpty()) {
            return
        }
        mutableState.value = mutableState.value.copy(query = current.dropLast(1))
    }

    /**
     * 清空当前搜索词。
     */
    fun clearQuery() {
        mutableState.value = mutableState.value.copy(query = "")
    }

    /**
     * 恢复初始片名搜索词。
     */
    fun restoreInitialQuery() {
        mutableState.value = mutableState.value.copy(query = mutableState.value.initialQuery)
    }

    /**
     * 执行弹幕剧集搜索。
     */
    suspend fun submitSearch() {
        val query = mutableState.value.query.trim()
        if (query.isEmpty()) {
            // 空查询直接进入正式错误态，和 Flutter TV 面板保持一致。
            mutableState.value = mutableState.value.copy(
                results = emptyList(),
                errorMessage = "请至少保留一个搜索字符",
                isLoading = false,
            )
            return
        }

        mutableState.value = mutableState.value.copy(
            isLoading = true,
            errorMessage = null,
        )
        val result = runCatching { searchEpisodes(query) }.getOrNull()
        mutableState.value = when {
            result == null -> mutableState.value.copy(
                results = emptyList(),
                errorMessage = "弹幕服务暂不可用",
                isLoading = false,
            )
            !result.success -> mutableState.value.copy(
                results = emptyList(),
                errorMessage = result.errorMessage.ifBlank { "搜索失败" },
                isLoading = false,
            )
            result.animes.isEmpty() -> mutableState.value.copy(
                results = emptyList(),
                errorMessage = "未找到相关弹幕",
                isLoading = false,
            )
            else -> mutableState.value.copy(
                results = result.animes,
                errorMessage = null,
                isLoading = false,
            )
        }
    }
}
