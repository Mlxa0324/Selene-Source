package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
import org.moontechlab.selene.tv.core.network.model.TvFavoriteResponse

/**
 * 校验 TV 收藏夹仓库映射契约。
 */
class TvFavoritesRepositoryTest {
    /**
     * 远端收藏夹应按保存时间倒序转成卡片。
     */
    @Test
    fun readFavorites_maps_remote_favorites_by_save_time() = runTest {
        val repository = TvFavoritesRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getFavorites(): Map<String, TvFavoriteResponse> {
                    return mapOf(
                        "source_a+video_a" to TvFavoriteResponse(
                            title = "收藏 A",
                            sourceName = "线路 A",
                            year = "2026",
                            cover = "a.jpg",
                            totalEpisodes = 10,
                            saveTime = 30L,
                            origin = "detail",
                        ),
                        "source_b+video_b" to TvFavoriteResponse(
                            title = "收藏 B",
                            saveTime = 20L,
                        ),
                    )
                }
            },
        )

        val cards = repository.readFavorites()

        assertThat(cards.map { it.id }).containsExactly("video_a", "video_b").inOrder()
        assertThat(cards.first().source).isEqualTo("source_a")
        assertThat(cards.first().sourceName).isEqualTo("线路 A")
        assertThat(cards.first().year).isEqualTo("2026")
        assertThat(cards.first().origin).isEqualTo("detail")
    }

    /**
     * 删除收藏时应使用 Flutter 兼容的 source+id key。
     */
    @Test
    fun deleteFavorite_uses_source_plus_id_key() = runTest {
        var deletedKey: String? = null
        val repository = TvFavoritesRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun deleteFavorite(key: String) {
                    deletedKey = key
                }
            },
        )

        repository.deleteFavorite(
            TvVideoCard(
                id = "video_a",
                source = "source_a",
                title = "收藏 A",
                posterUrl = "",
            ),
        )

        assertThat(deletedKey).isEqualTo("source_a+video_a")
    }

    /**
     * 保存收藏时应按 Flutter 请求体写入 key + favorite 字段。
     */
    @Test
    fun saveFavorite_posts_flutter_compatible_payload() = runTest {
        var savedKey: String? = null
        var savedTitle: String? = null
        val repository = TvFavoritesRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun saveFavorite(
                    request: org.moontechlab.selene.tv.core.network.model.TvFavoriteUpsertRequest,
                ) {
                    savedKey = request.key
                    savedTitle = request.favorite.title
                }
            },
        )

        repository.saveFavorite(
            source = "source_a",
            videoId = "video_a",
            title = "痴迷",
            sourceName = "爱奇艺",
            year = "2025",
            cover = "cover.jpg",
            totalEpisodes = 1,
        )

        assertThat(savedKey).isEqualTo("source_a+video_a")
        assertThat(savedTitle).isEqualTo("痴迷")
    }

    /**
     * 收藏回显应按 source+id 精确匹配。
     */
    @Test
    fun isFavorite_matches_source_and_id() = runTest {
        val repository = TvFavoritesRepository(
            api = object : FakeSeleneTvApi() {
                override suspend fun getFavorites(): Map<String, TvFavoriteResponse> {
                    return mapOf(
                        "source_a+video_a" to TvFavoriteResponse(title = "A"),
                        "source_b+video_a" to TvFavoriteResponse(title = "B"),
                    )
                }
            },
        )

        assertThat(repository.isFavorite(source = "source_a", videoId = "video_a")).isTrue()
        assertThat(repository.isFavorite(source = "source_c", videoId = "video_a")).isFalse()
    }
}
