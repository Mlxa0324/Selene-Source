package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordResponse
import org.moontechlab.selene.tv.core.network.model.TvPlayRecordUpsertRequest

/**
 * 校验 TV 播放历史仓库映射契约。
 */
class TvPlaybackRepositoryTest {
    @Before
    fun clearSharedContinueWatchingCache() {
        // 避免用例间共享进程缓存互相污染。
        TvPlaybackRepository.sharedContinueWatchingCache.clear()
    }

    /**
     * 继续观看 TTL 默认 1 天。
     */
    @Test
    fun continue_watching_cache_ttl_is_one_day() {
        assertThat(TvPlaybackRepository.CONTINUE_WATCHING_CACHE_TTL_MS).isEqualTo(86_400_000L)
    }

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
            continueWatchingCache = ContinueWatchingCache(),
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
            continueWatchingCache = ContinueWatchingCache(),
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
            continueWatchingCache = ContinueWatchingCache(),
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
            continueWatchingCache = ContinueWatchingCache(),
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
        var getCount = 0
        val cache = ContinueWatchingCache()
        val repository = TvPlaybackRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> {
                    getCount += 1
                    return store.toMap()
                }

                override suspend fun deletePlayRecord(key: String) {
                    deleted += key
                    store.remove(key)
                }
            },
            continueWatchingCache = cache,
        )

        val cards = repository.readContinueWatching()
        // 第二次读应命中 1 天缓存，不再打 getPlayRecords。
        val cached = repository.readContinueWatching()

        assertThat(deleted).containsExactly("source_old+id_old")
        assertThat(cards.map { it.id }).containsExactly("id_new", "id_x").inOrder()
        assertThat(cached).isEqualTo(cards)
        // 首次：purge 前 1 次 + 映射 1 次；二次命中缓存不增加。
        assertThat(getCount).isEqualTo(2)
    }

    /**
     * TTL 内命中缓存；过期后重新拉远端。
     */
    @Test
    fun readContinueWatching_refetches_after_ttl_expires() = runTest {
        var now = 1_000_000L
        var getCount = 0
        val store = mutableMapOf(
            "source_a+video_a" to TvPlayRecordResponse(
                title = "续看",
                searchTitle = "续看",
                saveTime = 20L,
                cover = "a.jpg",
            ),
        )
        val repository = TvPlaybackRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> {
                    getCount += 1
                    return store.toMap()
                }
            },
            continueWatchingCache = ContinueWatchingCache(
                ttlMs = TvPlaybackRepository.CONTINUE_WATCHING_CACHE_TTL_MS,
                nowMs = { now },
            ),
        )

        repository.readContinueWatching()
        now += TvPlaybackRepository.CONTINUE_WATCHING_CACHE_TTL_MS - 1
        repository.readContinueWatching()
        now += 2
        repository.readContinueWatching()

        // 首次 2 次 get（purge+map）；TTL 内 0；过期后再 2 次。
        assertThat(getCount).isEqualTo(4)
    }

    /**
     * 保存播放记录后必须失效缓存，下次读取重新请求。
     */
    @Test
    fun savePlayRecord_invalidates_continue_watching_cache() = runTest {
        var getCount = 0
        val store = mutableMapOf(
            "source_a+video_a" to TvPlayRecordResponse(
                title = "续看",
                searchTitle = "续看",
                saveTime = 20L,
            ),
        )
        val repository = TvPlaybackRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getPlayRecords(): Map<String, TvPlayRecordResponse> {
                    getCount += 1
                    return store.toMap()
                }

                override suspend fun savePlayRecord(request: TvPlayRecordUpsertRequest) {
                    store[request.key] = TvPlayRecordResponse(
                        title = request.record.title,
                        searchTitle = request.record.searchTitle,
                        saveTime = request.record.saveTime,
                    )
                }
            },
            continueWatchingCache = ContinueWatchingCache(),
        )

        repository.readContinueWatching()
        val afterFirst = getCount
        repository.savePlayRecord(
            TvVideoCard(
                id = "video_a",
                source = "source_a",
                title = "续看",
                posterUrl = "",
                searchTitle = "续看",
                saveTime = 99L,
            ),
        )
        repository.readContinueWatching()

        assertThat(afterFirst).isEqualTo(2)
        // save 后 purge 可能再 get；read 必须再次 get，不能仍用旧缓存。
        assertThat(getCount).isGreaterThan(afterFirst)
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
            continueWatchingCache = ContinueWatchingCache(),
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
