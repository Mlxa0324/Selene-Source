package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvDanmakuEpisodePayload
import org.moontechlab.selene.tv.core.data.storage.TvDanmakuManualMatchRecord
import org.moontechlab.selene.tv.core.data.storage.TvPreferencesStore

/**
 * TV 弹幕手动匹配仓库。
 *
 * @property preferencesStore TV 偏好存储。
 */
class TvDanmakuManualMatchRepository(
    private val preferencesStore: TvPreferencesStore,
) {
    /**
     * 保存手动匹配结果，并把后续弹幕集映射到后续视频集。
     *
     * @param source 播放来源标识。
     * @param videoId 视频 ID。
     * @param episodeIndex 当前视频集下标，从 0 开始。
     * @param selectedDanmakuEpisodeId 当前选中的弹幕剧集 ID。
     * @param searchKeyword 手动匹配搜索词。
     * @param fallbackTitle 视频标题，用于记录同标题最近搜索词。
     * @param orderedEpisodes 当前动画候选下的有序弹幕剧集。
     * @param selectedEpisodeOffset 当前选中弹幕剧集在候选列表中的下标。
     */
    suspend fun saveManualSelection(
        source: String,
        videoId: String,
        episodeIndex: Int,
        selectedDanmakuEpisodeId: Int,
        searchKeyword: String,
        fallbackTitle: String,
        orderedEpisodes: List<TvDanmakuEpisodePayload>,
        selectedEpisodeOffset: Int,
    ) {
        val cleanKeyword = searchKeyword.trim()
        if (
            source.isBlank() ||
            videoId.isBlank() ||
            selectedDanmakuEpisodeId <= 0 ||
            selectedEpisodeOffset !in orderedEpisodes.indices
        ) {
            return
        }
        orderedEpisodes.drop(selectedEpisodeOffset).forEachIndexed { offset, episode ->
            val mappedEpisodeId = if (offset == 0) {
                selectedDanmakuEpisodeId
            } else {
                episode.episodeId
            }
            // 从当前集开始顺延保存，保持 Flutter TV 手动匹配整季映射习惯。
            preferencesStore.saveDanmakuManualMatch(
                source = source,
                videoId = videoId,
                episodeIndex = episodeIndex + offset,
                episodeId = mappedEpisodeId,
                searchKeyword = cleanKeyword,
            )
        }
        preferencesStore.saveLastDanmakuManualMatchQueryForTitle(
            title = fallbackTitle,
            searchKeyword = cleanKeyword,
        )
    }

    /**
     * 读取单集手动匹配记录。
     *
     * @param source 播放来源标识。
     * @param videoId 视频 ID。
     * @param episodeIndex 剧集下标。
     * @return 手动匹配记录。
     */
    suspend fun getManualMatch(
        source: String,
        videoId: String,
        episodeIndex: Int,
    ): TvDanmakuManualMatchRecord? {
        return preferencesStore.getDanmakuManualMatch(
            source = source,
            videoId = videoId,
            episodeIndex = episodeIndex,
        )
    }

    /**
     * 读取同标题最近一次手动匹配搜索词。
     *
     * @param title 视频标题。
     * @return 最近搜索词。
     */
    suspend fun getLastManualMatchQueryForTitle(title: String): String? {
        return preferencesStore.getLastDanmakuManualMatchQueryForTitle(title)
    }
}
