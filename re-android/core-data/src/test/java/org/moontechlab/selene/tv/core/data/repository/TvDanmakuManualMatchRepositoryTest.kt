package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvDanmakuEpisodePayload
import org.moontechlab.selene.tv.core.data.storage.TvPreferencesStore

/**
 * 校验 TV 弹幕手动匹配持久化契约。
 */
class TvDanmakuManualMatchRepositoryTest {
    /**
     * 保存整季匹配时必须从当前选中 offset 起映射到后续视频集。
     */
    @Test
    fun saveManualSelection_maps_selected_episode_and_following_episodes() = runTest {
        val repository = TvDanmakuManualMatchRepository(preferencesStore = TvPreferencesStore())
        val orderedEpisodes = listOf(
            TvDanmakuEpisodePayload(episodeId = 9001, episodeTitle = "第 1 集"),
            TvDanmakuEpisodePayload(episodeId = 9002, episodeTitle = "第 2 集"),
            TvDanmakuEpisodePayload(episodeId = 9003, episodeTitle = "第 3 集"),
        )

        repository.saveManualSelection(
            source = "source-a",
            videoId = "video-1",
            episodeIndex = 4,
            selectedDanmakuEpisodeId = 9002,
            searchKeyword = "测试番剧",
            fallbackTitle = "测试影片",
            orderedEpisodes = orderedEpisodes,
            selectedEpisodeOffset = 1,
        )

        val current = repository.getManualMatch("source-a", "video-1", 4)
        val next = repository.getManualMatch("source-a", "video-1", 5)
        val previous = repository.getManualMatch("source-a", "video-1", 3)

        assertThat(current?.episodeId).isEqualTo(9002)
        assertThat(current?.searchKeyword).isEqualTo("测试番剧")
        assertThat(next?.episodeId).isEqualTo(9003)
        assertThat(previous).isNull()
        assertThat(repository.getLastManualMatchQueryForTitle("测试影片")).isEqualTo("测试番剧")
    }
}
