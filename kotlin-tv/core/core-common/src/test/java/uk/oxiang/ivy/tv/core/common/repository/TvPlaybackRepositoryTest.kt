package uk.oxiang.ivy.tv.core.common.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import uk.oxiang.ivy.tv.core.common.model.TvVideoCard
import uk.oxiang.ivy.tv.core.common.network.model.TvPlayRecordResponse
import org.junit.Test

/**
 * [TvPlaybackRepository] 契约测试：`source+id` key 拆分与 DTO -> 业务模型映射。
 */
class TvPlaybackRepositoryTest {

    private class FakeApiWithRecords(
        private val records: Map<String, TvPlayRecordResponse>,
    ) : FakeSeleneTvApi() {
        override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> = records
    }

    @Test
    fun readContinueWatching_mapsSourceAndIdFromCompositeKey() = runTest {
        val api = FakeApiWithRecords(
            mapOf(
                "vod1+abc123" to TvPlayRecordResponse(
                    title = "测试剧集",
                    sourceName = "线路一",
                    year = "2024",
                    cover = "https://example.com/cover.jpg",
                    index = 3,
                    totalEpisodes = 12,
                    playTime = 120,
                    totalTime = 1500,
                    saveTime = 1_700_000_000L,
                    searchTitle = "测试剧集原名",
                ),
            ),
        )
        val repository = TvPlaybackRepository(api = api)

        val result = repository.readContinueWatching()

        assertThat(result).hasSize(1)
        val card = result.first()
        assertThat(card.source).isEqualTo("vod1")
        assertThat(card.id).isEqualTo("abc123")
        assertThat(card.title).isEqualTo("测试剧集")
        assertThat(card.episodeIndex).isEqualTo(3)
        assertThat(card.totalEpisodes).isEqualTo(12)
        assertThat(card.playTime).isEqualTo(120)
        assertThat(card.saveTime).isEqualTo(1_700_000_000L)
    }

    @Test
    fun readContinueWatching_sortsBySaveTimeDescending() = runTest {
        val api = FakeApiWithRecords(
            mapOf(
                "vod1+older" to TvPlayRecordResponse(title = "旧记录", saveTime = 100L),
                "vod1+newer" to TvPlayRecordResponse(title = "新记录", saveTime = 200L),
            ),
        )
        val repository = TvPlaybackRepository(api = api)

        val result = repository.readContinueWatching()

        assertThat(result.map { it.title }).containsExactly("新记录", "旧记录").inOrder()
    }

    @Test
    fun readContinueWatching_withoutApi_returnsInjectedFallback() = runTest {
        val fallback = listOf(TvVideoCard(id = "1", title = "本地记录", posterUrl = ""))
        val repository = TvPlaybackRepository(api = null, continueWatching = fallback)

        val result = repository.readContinueWatching()

        assertThat(result).isEqualTo(fallback)
    }

    @Test
    fun recordIdentity_fromKey_withoutPlusSeparator_treatsWholeStringAsId() {
        val identity = TvRecordIdentity.fromKey("plain-id-without-source")

        assertThat(identity.source).isEmpty()
        assertThat(identity.id).isEqualTo("plain-id-without-source")
    }
}
