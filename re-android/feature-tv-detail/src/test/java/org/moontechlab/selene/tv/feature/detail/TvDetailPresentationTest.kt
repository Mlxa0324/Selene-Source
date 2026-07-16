package org.moontechlab.selene.tv.feature.detail

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvEpisode
import org.moontechlab.selene.tv.core.data.model.TvVideoCard
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
     * 只有一个选集分组时，不展示下方分组切换条，避免单集影片出现 1-1 空白槽。
     */
    @Test
    fun shouldShowDetailEpisodeGroupChoices_only_shows_for_multiple_groups() {
        assertThat(shouldShowDetailEpisodeGroupChoices(groupCount = 0)).isFalse()
        assertThat(shouldShowDetailEpisodeGroupChoices(groupCount = 1)).isFalse()
        assertThat(shouldShowDetailEpisodeGroupChoices(groupCount = 2)).isTrue()
    }

    /**
     * Idle 无数据时仍展示推荐区（骨架占位），底部动作始终展示。
     */
    @Test
    fun buildDetailLayoutSections_keeps_recommend_skeleton_while_idle_without_cards() {
        val sections = buildDetailLayoutSections(
            sources = listOf(source(id = "a", episodeCount = 1)),
            episodes = episodes(count = 1),
            recommends = emptyList(),
            recommendLoadState = TvDetailRecommendLoadState.Idle,
        )

        assertThat(sections.showSources).isTrue()
        assertThat(sections.showEpisodes).isTrue()
        assertThat(sections.showRecommends).isTrue()
        assertThat(sections.showBottomActions).isTrue()
    }

    /**
     * 确认无推荐（Empty）后才隐藏推荐区，避免空结果仍占骨架。
     */
    @Test
    fun buildDetailLayoutSections_hides_recommend_when_empty_result() {
        val sections = buildDetailLayoutSections(
            sources = listOf(source(id = "a", episodeCount = 1)),
            episodes = episodes(count = 1),
            recommends = emptyList(),
            recommendLoadState = TvDetailRecommendLoadState.Empty,
        )

        assertThat(sections.showRecommends).isFalse()
        assertThat(sections.showBottomActions).isTrue()
    }

    /**
     * 加载中必须展示推荐区骨架，不能整块消失。
     */
    @Test
    fun buildDetailLayoutSections_shows_recommend_skeleton_while_loading() {
        val sections = buildDetailLayoutSections(
            sources = listOf(source(id = "a", episodeCount = 1)),
            episodes = episodes(count = 1),
            recommends = emptyList(),
            recommendLoadState = TvDetailRecommendLoadState.Loading,
        )

        assertThat(sections.showRecommends).isTrue()
    }

    /**
     * 推荐非空时，应同时展示推荐区和底部动作区。
     */
    @Test
    fun buildDetailLayoutSections_shows_recommends_and_bottom_actions_when_recommends_are_present() {
        val sections = buildDetailLayoutSections(
            sources = listOf(source(id = "a", episodeCount = 1)),
            episodes = episodes(count = 1),
            recommends = listOf(
                TvVideoCard(
                    id = "recommend-1",
                    source = "douban",
                    title = "推荐影片",
                    posterUrl = "https://img.test/recommend.jpg",
                ),
            ),
        )

        assertThat(sections.showRecommends).isTrue()
        assertThat(sections.showBottomActions).isTrue()
    }

    /**
     * 推荐加载中可展示骨架，但焦点图必须按卡片数=0 跳过推荐区。
     */
    @Test
    fun focus_graph_skips_recommend_while_loading_without_cards() {
        val graph = TvDetailFocusGraph(
            sourceCount = 1,
            episodeCount = 5,
            recommendCount = 0,
        )
        val fromEpisode = TvDetailFocusPosition.episode(index = 0)
        val move = graph.resolve(fromEpisode, TvDetailFocusDirection.Down)
        // 无推荐卡片时不应进入 Recommend，避免落在未加载区域。
        assertThat(move.target.area).isNotEqualTo(TvDetailFocusArea.Recommend)
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

    /**
     * 选集/分组固定焦点槽：前 2 项不滚，之后焦点停在第 2 格、列表推进。
     */
    @Test
    fun resolveDetailPinnedFirstVisibleIndex_keeps_focus_slot_stable() {
        assertThat(resolveDetailPinnedFirstVisibleIndex(focusedIndex = 0, itemCount = 20)).isEqualTo(0)
        assertThat(resolveDetailPinnedFirstVisibleIndex(focusedIndex = 1, itemCount = 20)).isEqualTo(0)
        assertThat(resolveDetailPinnedFirstVisibleIndex(focusedIndex = 2, itemCount = 20)).isEqualTo(1)
        assertThat(resolveDetailPinnedFirstVisibleIndex(focusedIndex = 5, itemCount = 20)).isEqualTo(4)
        // 末段不再无限制推进，保证最后几项仍能停在固定槽附近。
        assertThat(resolveDetailPinnedFirstVisibleIndex(focusedIndex = 19, itemCount = 20)).isEqualTo(18)
    }
}
