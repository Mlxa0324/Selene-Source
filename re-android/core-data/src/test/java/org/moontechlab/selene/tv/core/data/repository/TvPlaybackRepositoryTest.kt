package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordResponse
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordUpsertRequest

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

    /**
     * 保存播放记录时，请求体必须与 Flutter `/api/playrecords` 保持一致。
     */
    @Test
    fun savePlayRecord_posts_flutter_compatible_body() = runTest {
        var savedRequest: TvPlayRecordUpsertRequest? = null
        val repository = TvPlaybackRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun savePlayRecord(request: TvPlayRecordUpsertRequest) {
                    savedRequest = request
                }
            },
        )

        repository.savePlayRecord(
            TvVideoCard(
                id = "video_a",
                source = "source_a",
                title = "测试影片",
                sourceName = "线路 A",
                year = "2026",
                posterUrl = "https://img.test/a.jpg",
                totalEpisodes = 24,
                episodeIndex = 3,
                playTime = 125,
                totalTime = 3_600,
                saveTime = 1_710_000_123_456L,
                searchTitle = "测试影片",
            ),
        )

        assertThat(savedRequest?.key).isEqualTo("source_a+video_a")
        assertThat(savedRequest?.record?.title).isEqualTo("测试影片")
        assertThat(savedRequest?.record?.sourceName).isEqualTo("线路 A")
        assertThat(savedRequest?.record?.cover).isEqualTo("https://img.test/a.jpg")
        assertThat(savedRequest?.record?.index).isEqualTo(3)
        assertThat(savedRequest?.record?.playTime).isEqualTo(125)
        assertThat(savedRequest?.record?.searchTitle).isEqualTo("测试影片")
    }

    /**
     * 保存时必须先 upsert 当前 key，再删除同名其它 key，不能先删后存。
     */
    @Test
    fun savePlayRecord_writes_current_before_deleting_same_title_duplicates() = runTest {
        val events = mutableListOf<String>()
        val store = mutableMapOf(
            "old_source+old_id" to TvPlayRecordResponse(
                title = "痴迷",
                searchTitle = "痴迷",
                saveTime = 10L,
            ),
            "source_a+video_a" to TvPlayRecordResponse(
                title = "痴迷",
                searchTitle = "痴迷",
                saveTime = 5L,
            ),
        )
        val repository = TvPlaybackRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> {
                    return store.toMap()
                }

                override suspend fun savePlayRecord(request: TvPlayRecordUpsertRequest) {
                    events += "save:${request.key}"
                    store[request.key] = TvPlayRecordResponse(
                        title = request.record.title,
                        searchTitle = request.record.searchTitle,
                        saveTime = request.record.saveTime,
                    )
                }

                override suspend fun deletePlayRecord(key: String) {
                    events += "delete:$key"
                    store.remove(key)
                }
            },
        )

        repository.savePlayRecord(
            TvVideoCard(
                id = "video_a",
                source = "source_a",
                title = "痴迷",
                posterUrl = "",
                searchTitle = "痴迷",
                saveTime = 99L,
            ),
        )

        assertThat(events.first()).isEqualTo("save:source_a+video_a")
        assertThat(events).contains("delete:old_source+old_id")
        assertThat(events).doesNotContain("delete:source_a+video_a")
        assertThat(store.keys).containsExactly("source_a+video_a")
    }

    /**
     * 读取继续观看时，同名多条应通过接口删到只剩最新一条。
     */
    @Test
    fun readContinueWatching_purges_same_title_duplicates_via_api() = runTest {
        val store = mutableMapOf(
            "source_old+id_old" to TvPlayRecordResponse(
                title = "痴迷",
                searchTitle = "痴迷",
                saveTime = 10L,
            ),
            "source_new+id_new" to TvPlayRecordResponse(
                title = "痴迷",
                searchTitle = "痴迷",
                saveTime = 30L,
            ),
            "source_x+id_x" to TvPlayRecordResponse(
                title = "另一部",
                searchTitle = "另一部",
                saveTime = 20L,
            ),
        )
        val deleted = mutableListOf<String>()
        val repository = TvPlaybackRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> {
                    return store.toMap()
                }

                override suspend fun deletePlayRecord(key: String) {
                    deleted += key
                    store.remove(key)
                }
            },
        )

        val cards = repository.readContinueWatching()

        assertThat(deleted).containsExactly("source_old+id_old")
        assertThat(cards.map { it.id }).containsExactly("id_new", "id_x").inOrder()
    }

    /**
     * 删除同名失败时不能丢掉刚保存的记录。
     */
    @Test
    fun savePlayRecord_keeps_saved_record_when_duplicate_delete_fails() = runTest {
        val store = mutableMapOf(
            "old_source+old_id" to TvPlayRecordResponse(
                title = "痴迷",
                searchTitle = "痴迷",
                saveTime = 10L,
            ),
        )
        val repository = TvPlaybackRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> {
                    return store.toMap()
                }

                override suspend fun savePlayRecord(request: TvPlayRecordUpsertRequest) {
                    store[request.key] = TvPlayRecordResponse(
                        title = request.record.title,
                        searchTitle = request.record.searchTitle,
                        saveTime = request.record.saveTime,
                    )
                }

                override suspend fun deletePlayRecord(key: String) {
                    error("delete failed")
                }
            },
        )

        repository.savePlayRecord(
            TvVideoCard(
                id = "video_a",
                source = "source_a",
                title = "痴迷",
                posterUrl = "",
                searchTitle = "痴迷",
                saveTime = 99L,
            ),
        )

        // 删重失败：新旧都在，但当前 key 一定还在。
        assertThat(store.keys).contains("source_a+video_a")
        assertThat(store.keys).contains("old_source+old_id")
    }

    /**
     * 标题规范化应折叠空白并忽略大小写。
     */
    @Test
    fun normalizePlayRecordTitle_collapses_whitespace_and_case() {
        assertThat(normalizePlayRecordTitle("  痴  迷 ", null)).isEqualTo("痴 迷")
        assertThat(normalizePlayRecordTitle("Title", " Search  Title ")).isEqualTo("search title")
        assertThat(normalizePlayRecordTitle(null, null)).isEmpty()
    }
}
