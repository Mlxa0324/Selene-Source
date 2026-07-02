package org.moontechlab.selene.tv.feature.detail

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoSource

/**
 * 校验 TV 详情页展示模型。
 */
class TvDetailPresentationTest {
    /**
     * 线路首次展示时，当前线路固定在首位，其余线路按剧集数倒序。
     */
    @Test
    fun buildDetailSourceOptions_pins_current_source_first_and_sorts_others_by_episode_count() {
        val options = buildDetailSourceOptions(
            sources = listOf(
                source(id = "a", episodeCount = 4),
                source(id = "b", episodeCount = 12),
                source(id = "c", episodeCount = 8),
                source(id = "d", episodeCount = 12),
            ),
            currentSourceId = "c",
            pinCurrentSource = true,
        )

        assertThat(options.map { option -> option.sourceId })
            .containsExactly("c", "b", "d", "a")
            .inOrder()
        assertThat(options.first().label).isEqualTo("线路 c")
        assertThat(options.first().trailingText).isEqualTo("（8）")
        assertThat(options.first().selected).isTrue()
    }

    /**
     * 用户主动切源后，线路按剧集数排序，相同集数保持原始顺序。
     */
    @Test
    fun buildDetailSourceOptions_sorts_by_episode_count_when_current_source_is_not_pinned() {
        val options = buildDetailSourceOptions(
            sources = listOf(
                source(id = "a", episodeCount = 4),
                source(id = "b", episodeCount = 12),
                source(id = "c", episodeCount = 8),
                source(id = "d", episodeCount = 12),
            ),
            currentSourceId = "c",
            pinCurrentSource = false,
        )

        assertThat(options.map { option -> option.sourceId })
            .containsExactly("b", "d", "c", "a")
            .inOrder()
    }

    /**
     * 选集按 20 集分组，并返回当前组的剧集选项。
     */
    @Test
    fun buildDetailEpisodeGroups_groups_episodes_by_twenty_and_marks_current_group() {
        val groups = buildDetailEpisodeGroups(
            episodes = episodes(count = 45),
            selectedEpisodeId = "ep-22",
            selectedGroupIndex = 1,
        )

        assertThat(groups.map { group -> group.label })
            .containsExactly("1-20", "21-40", "41-45")
            .inOrder()
        assertThat(groups[1].selected).isTrue()
        assertThat(groups[1].episodes.map { episode -> episode.episodeId }.first()).isEqualTo("ep-21")
        assertThat(groups[1].episodes.map { episode -> episode.episodeId }.last()).isEqualTo("ep-40")
        assertThat(groups[1].episodes.first { episode -> episode.episodeId == "ep-22" }.selected).isTrue()
    }

    /**
     * 只有一个选集分组时，不展示上方分组切换条，避免单集影片出现 1-1 空白槽。
     */
    @Test
    fun shouldShowDetailEpisodeGroupChoices_only_shows_for_multiple_groups() {
        assertThat(shouldShowDetailEpisodeGroupChoices(groupCount = 0)).isFalse()
        assertThat(shouldShowDetailEpisodeGroupChoices(groupCount = 1)).isFalse()
        assertThat(shouldShowDetailEpisodeGroupChoices(groupCount = 2)).isTrue()
    }

    /**
     * 推荐为空时，布局不渲染推荐区和底部动作。
     */
    @Test
    fun buildDetailLayoutSections_hides_recommend_and_bottom_actions_when_recommends_are_empty() {
        val sections = buildDetailLayoutSections(
            sources = listOf(source(id = "a", episodeCount = 1)),
            episodes = episodes(count = 1),
            recommends = emptyList(),
        )

        assertThat(sections.showSources).isTrue()
        assertThat(sections.showEpisodes).isTrue()
        assertThat(sections.showRecommends).isFalse()
        assertThat(sections.showBottomActions).isFalse()
    }

    /**
     * 构造播放线路。
     *
     * @param id 线路 ID。
     * @param episodeCount 剧集数量。
     * @return 播放线路。
     */
    private fun source(
        id: String,
        episodeCount: Int,
    ): TvVideoSource {
        return TvVideoSource(
            id = id,
            source = id,
            videoId = "video-$id",
            name = "线路 $id",
            episodes = episodes(episodeCount),
        )
    }

    /**
     * 构造剧集列表。
     *
     * @param count 剧集数量。
     * @return 剧集列表。
     */
    private fun episodes(count: Int): List<TvEpisode> {
        return List(count) { index ->
            TvEpisode(
                id = "ep-${index + 1}",
                title = "第 ${index + 1} 集",
                url = "https://cdn.test/${index + 1}.m3u8",
            )
        }
    }
}
