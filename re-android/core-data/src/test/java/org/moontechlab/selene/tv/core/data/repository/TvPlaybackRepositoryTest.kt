package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordResponse

/**
 * 校验 TV 播放历史仓库映射契约。
 */
class TvPlaybackRepositoryTest {
    /**
     * 远端播放历史应按保存时间倒序转成卡片。
     */
    @Test
    fun readContinueWatching_maps_remote_records_by_save_time() = runTest {
        val repository = TvPlaybackRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> {
                    return mapOf(
                        "source_b+video_b" to TvPlayRecordResponse(
                            title = "旧记录",
                            sourceName = "线路 B",
                            cover = "b.jpg",
                            index = 1,
                            totalEpisodes = 12,
                            playTime = 60,
                            totalTime = 1200,
                            saveTime = 10L,
                            searchTitle = "旧记录",
                        ),
                        "source_a+video_a" to TvPlayRecordResponse(
                            title = "新记录",
                            sourceName = "线路 A",
                            cover = "a.jpg",
                            index = 2,
                            totalEpisodes = 24,
                            playTime = 90,
                            totalTime = 1800,
                            saveTime = 20L,
                            searchTitle = "新记录",
                        ),
                    )
                }
            },
        )

        val cards = repository.readContinueWatching()

        assertThat(cards.map { it.id }).containsExactly("video_a", "video_b").inOrder()
        assertThat(cards.first().source).isEqualTo("source_a")
        assertThat(cards.first().sourceName).isEqualTo("线路 A")
        assertThat(cards.first().posterUrl).isEqualTo("a.jpg")
        assertThat(cards.first().episodeIndex).isEqualTo(2)
        assertThat(cards.first().playTime).isEqualTo(90)
    }

    /**
     * 远端异常不能被吞成空列表。
     */
    @Test
    fun readContinueWatching_keeps_remote_failure_visible() = runTest {
        val repository = TvPlaybackRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> {
                    error("播放历史接口失败")
                }
            },
        )

        val error = runCatching { repository.readContinueWatching() }.exceptionOrNull()

        assertThat(error).isInstanceOf(IllegalStateException::class.java)
        assertThat(error).hasMessageThat().contains("播放历史接口失败")
    }
}
