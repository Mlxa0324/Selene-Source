package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.SeleneTvApi
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordResponse
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordUpsertBody
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordUpsertRequest

/**
 * TV 播放记录仓库。
 *
 * 继续观看同名去重约定：
 * - 利用 `/api/playrecords` 读写，不做纯前端列表过滤；
 * - **先保证保留记录已在服务端**（先保存/先选定保留 key），再删同名其它 key；
 * - 删除失败时保留重复项，绝不“先删再存”导致唯一副本丢失。
 *
 * @property api TV 服务端接口。
 * @property continueWatching 首期注入的继续观看列表。
 */
class TvPlaybackRepository(
    private val api: SeleneTvApi? = null,
    private val continueWatching: List<TvVideoCard> = emptyList(),
) {
    /**
     * 读取继续观看列表。
     *
     * 拉取后会按同名策略清理服务端多余记录，再返回最新列表。
     *
     * @return 按最近播放排序的影视卡片列表。
     */
    suspend fun readContinueWatching(): List<TvVideoCard> {
        val remoteApi = api ?: return continueWatching
        // 远端接口成功但为空时返回空列表；异常交给调用方展示错误态。
        val remoteRecords = remoteApi.getPlayRecords()
        // 仅删除“非保留”的同名 key，保留项始终先存在于服务端。
        purgeDuplicateTitleRecords(
            remoteApi = remoteApi,
            records = remoteRecords,
            preferredKeepKey = null,
        )
        return remoteApi.getPlayRecords()
            .map { (key, record) -> record.toVideoCard(key) }
            .sortedByDescending { card -> card.saveTime }
    }

    /**
     * 保存单条播放历史。
     *
     * 顺序：先 upsert 当前 key，再删同名其它 key，避免先删后存失败丢数据。
     *
     * @param video 当前播放记录卡片。
     */
    suspend fun savePlayRecord(video: TvVideoCard) {
        val remoteApi = api ?: return
        val keepKey = video.toRecordKey()
        // 1) 先写入/更新当前记录，确保服务端已有最新副本。
        remoteApi.savePlayRecord(video.toUpsertRequest())
        // 2) 再清理同名其它线路/id 的旧记录；失败只影响去重，不丢当前记录。
        val remoteRecords = runCatching { remoteApi.getPlayRecords() }.getOrNull() ?: return
        purgeDuplicateTitleRecords(
            remoteApi = remoteApi,
            records = remoteRecords,
            preferredKeepKey = keepKey,
            preferredTitle = video.title,
            preferredSearchTitle = video.searchTitle,
        )
    }

    /**
     * 删除单条播放历史。
     *
     * @param video 播放历史卡片。
     */
    suspend fun deletePlayRecord(video: TvVideoCard) {
        deletePlayRecordByKey(video.toRecordKey())
    }

    /**
     * 按后端 key 删除单条播放历史。
     *
     * @param key `source+id` 格式的播放记录 key。
     */
    suspend fun deletePlayRecordByKey(key: String) {
        api?.deletePlayRecord(key)
    }

    /**
     * 清空播放历史。
     */
    suspend fun clearPlayRecords() {
        api?.clearPlayRecords()
    }

    /**
     * 按同名分组清理播放记录，每组只保留一条。
     *
     * 保留策略：
     * 1. 若指定 [preferredKeepKey] 且该 key 仍存在（或刚保存），优先保留它；
     * 2. 否则保留同组内 `save_time` 最新的一条；
     * 3. 仅删除其它 key，从不删除“保留 key”。
     *
     * @param remoteApi 远端 API。
     * @param records 当前服务端全量记录。
     * @param preferredKeepKey 优先保留的 key（保存场景传入）。
     * @param preferredTitle 保存场景的标题，用于定位同名组。
     * @param preferredSearchTitle 保存场景的搜索标题。
     */
    private suspend fun purgeDuplicateTitleRecords(
        remoteApi: SeleneTvApi,
        records: Map<String, TvPlayRecordResponse>,
        preferredKeepKey: String?,
        preferredTitle: String? = null,
        preferredSearchTitle: String? = null,
    ) {
        if (records.isEmpty()) {
            return
        }
        val groups = records.entries.groupBy { (key, record) ->
            normalizePlayRecordTitle(
                title = record.title,
                searchTitle = record.searchTitle,
            )
        }
        for ((titleKey, entries) in groups) {
            if (titleKey.isBlank() || entries.size <= 1) {
                continue
            }
            val keepKey = resolveKeepKey(
                entries = entries,
                preferredKeepKey = preferredKeepKey,
                preferredTitleKey = normalizePlayRecordTitle(
                    title = preferredTitle,
                    searchTitle = preferredSearchTitle,
                ).takeIf { key -> key == titleKey },
            ) ?: continue
            // 只删非保留项；保留项已在 map 中或刚 upsert，不会出现“删光再写”。
            entries.asSequence()
                .map { entry -> entry.key }
                .filter { key -> key != keepKey }
                .forEach { duplicateKey ->
                    runCatching { remoteApi.deletePlayRecord(duplicateKey) }
                }
        }
    }

    /**
     * 在同名组内决定保留哪一条记录的 key。
     *
     * @param entries 同名组全部记录。
     * @param preferredKeepKey 调用方希望保留的 key。
     * @param preferredTitleKey 若与本组标题一致，才采纳 preferredKeepKey。
     * @return 保留 key；组为空时返回 null。
     */
    private fun resolveKeepKey(
        entries: List<Map.Entry<String, TvPlayRecordResponse>>,
        preferredKeepKey: String?,
        preferredTitleKey: String?,
    ): String? {
        if (entries.isEmpty()) {
            return null
        }
        // 保存场景：本组就是刚写入的那条标题 → 固定保留 preferred key（已先 upsert）。
        // 即使后续 getPlayRecords 暂时看不到它，也只删组内其它 key，不会动 preferred。
        if (!preferredKeepKey.isNullOrBlank() && !preferredTitleKey.isNullOrBlank()) {
            return preferredKeepKey
        }
        // 读列表场景：保留同组内最近播放的一条。
        return entries.maxByOrNull { entry -> entry.value.saveTime ?: 0L }?.key
    }

    /**
     * 将播放记录响应转换成 TV 卡片模型。
     *
     * @param key 后端 `source+id` 记录 key。
     * @return TV 影视卡片。
     */
    private fun TvPlayRecordResponse.toVideoCard(key: String): TvVideoCard {
        val identity = TvRecordIdentity.fromKey(key)
        return TvVideoCard(
            id = identity.id,
            source = identity.source,
            title = title.orEmpty(),
            sourceName = sourceName.orEmpty(),
            year = year.orEmpty(),
            posterUrl = cover.orEmpty(),
            totalEpisodes = totalEpisodes ?: 0,
            episodeIndex = index ?: 0,
            playTime = playTime ?: 0,
            totalTime = totalTime ?: 0,
            saveTime = saveTime ?: 0,
            searchTitle = searchTitle.orEmpty(),
        )
    }

    /**
     * 将卡片转换成播放记录 key。
     *
     * @return `source+id` 格式的 key。
     */
    private fun TvVideoCard.toRecordKey(): String {
        return if (source.isBlank()) id else "$source+$id"
    }

    /**
     * 将卡片转换成 Flutter 兼容的播放历史保存请求。
     *
     * @return `/api/playrecords` 请求体。
     */
    private fun TvVideoCard.toUpsertRequest(): TvPlayRecordUpsertRequest {
        val safePlayTime = playTime.coerceAtLeast(0)
        val safeTotalTime = totalTime
            .coerceAtLeast(0)
            .coerceAtLeast(if (safePlayTime > 0) safePlayTime + 1 else 0)
        return TvPlayRecordUpsertRequest(
            key = toRecordKey(),
            record = TvPlayRecordUpsertBody(
                title = title,
                sourceName = sourceName,
                year = year,
                cover = posterUrl,
                index = episodeIndex.coerceAtLeast(1),
                totalEpisodes = totalEpisodes.coerceAtLeast(0),
                playTime = safePlayTime,
                totalTime = safeTotalTime,
                saveTime = saveTime.coerceAtLeast(0L),
                searchTitle = searchTitle.ifBlank { title },
            ),
        )
    }
}

/**
 * 规范化播放记录标题，用于同名去重。
 *
 * 优先 searchTitle（跨源更稳），否则 title；去首尾空白并折叠空白，忽略大小写。
 *
 * @param title 展示标题。
 * @param searchTitle 搜索/回源标题。
 * @return 规范化后的同名键；全空时返回空串。
 */
internal fun normalizePlayRecordTitle(
    title: String?,
    searchTitle: String?,
): String {
    val raw = searchTitle?.trim().orEmpty().ifBlank {
        title?.trim().orEmpty()
    }
    if (raw.isEmpty()) {
        return ""
    }
    return raw
        .replace(Regex("\\s+"), " ")
        .lowercase()
}

/**
 * 后端播放记录 key 拆分结果。
 *
 * @property source 播放来源标识。
 * @property id 视频 ID。
 */
internal data class TvRecordIdentity(
    val source: String,
    val id: String,
) {
    companion object {
        /**
         * 按 Flutter `source+id` 规则解析记录 key。
         *
         * @param key 后端记录 key。
         * @return 拆分后的来源和 ID。
         */
        fun fromKey(key: String): TvRecordIdentity {
            val parts = key.split("+", limit = 2)
            return if (parts.size > 1) {
                TvRecordIdentity(source = parts[0], id = parts[1])
            } else {
                TvRecordIdentity(source = "", id = key)
            }
        }
    }
}
