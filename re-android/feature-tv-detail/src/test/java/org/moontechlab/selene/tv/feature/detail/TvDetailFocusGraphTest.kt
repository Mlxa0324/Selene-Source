package org.moontechlab.selene.tv.feature.detail

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 TV 详情页显式焦点图。
 */
class TvDetailFocusGraphTest {
    /**
     * 线路首尾继续横向移动时应停留在来源链路，不跳到其它区域。
     */
    @Test
    fun resolveDetailFocusMove_keeps_source_focus_at_horizontal_boundaries() {
        val graph = focusGraph(sourceCount = 3, episodeCount = 12)

        val left = graph.resolve(
            from = TvDetailFocusPosition.source(index = 0),
            direction = TvDetailFocusDirection.Left,
        )
        val right = graph.resolve(
            from = TvDetailFocusPosition.source(index = 2),
            direction = TvDetailFocusDirection.Right,
        )

        assertThat(left.target).isEqualTo(TvDetailFocusPosition.source(index = 0))
        assertThat(left.boundary).isTrue()
        assertThat(right.target).isEqualTo(TvDetailFocusPosition.source(index = 2))
        assertThat(right.boundary).isTrue()
    }

    /**
     * 全屏和收藏按钮向下时优先进入当前线路。
     */
    @Test
    fun resolveDetailFocusMove_moves_from_hero_actions_down_to_current_source() {
        val graph = focusGraph(sourceCount = 4, currentSourceIndex = 2, episodeCount = 12)

        val fullscreenDown = graph.resolve(
            from = TvDetailFocusPosition.area(TvDetailFocusArea.Fullscreen),
            direction = TvDetailFocusDirection.Down,
        )
        val favoriteDown = graph.resolve(
            from = TvDetailFocusPosition.area(TvDetailFocusArea.Favorite),
            direction = TvDetailFocusDirection.Down,
        )

        assertThat(fullscreenDown.target).isEqualTo(TvDetailFocusPosition.source(index = 2))
        assertThat(favoriteDown.target).isEqualTo(TvDetailFocusPosition.source(index = 2))
    }

    /**
     * 来源和选集上下移动应保持最近链路。
     */
    @Test
    fun resolveDetailFocusMove_moves_between_source_and_nearest_episode() {
        val graph = focusGraph(sourceCount = 4, currentSourceIndex = 1, episodeCount = 24, currentEpisodeIndex = 6)

        val sourceDown = graph.resolve(
            from = TvDetailFocusPosition.source(index = 1),
            direction = TvDetailFocusDirection.Down,
        )
        val episodeUp = graph.resolve(
            from = TvDetailFocusPosition.episode(index = 6),
            direction = TvDetailFocusDirection.Up,
        )

        assertThat(sourceDown.target).isEqualTo(TvDetailFocusPosition.episode(index = 6))
        assertThat(episodeUp.target).isEqualTo(TvDetailFocusPosition.source(index = 1))
    }

    /**
     * 选集左右跨组时目标仍是选集区域。
     */
    @Test
    fun resolveDetailFocusMove_crosses_episode_groups_without_leaving_episode_chain() {
        val graph = focusGraph(sourceCount = 2, episodeCount = 45, currentEpisodeIndex = 19)

        val nextGroup = graph.resolve(
            from = TvDetailFocusPosition.episode(index = 19),
            direction = TvDetailFocusDirection.Right,
        )
        val previousGroup = graph.resolve(
            from = TvDetailFocusPosition.episode(index = 20),
            direction = TvDetailFocusDirection.Left,
        )

        assertThat(nextGroup.target).isEqualTo(TvDetailFocusPosition.episode(index = 20))
        assertThat(nextGroup.boundary).isFalse()
        assertThat(previousGroup.target).isEqualTo(TvDetailFocusPosition.episode(index = 19))
        assertThat(previousGroup.boundary).isFalse()
    }

    /**
     * 无推荐时，选集分组向下停留当前链路。
     */
    @Test
    fun resolveDetailFocusMove_keeps_episode_group_when_recommends_are_empty() {
        val graph = focusGraph(sourceCount = 2, episodeCount = 45, recommendCount = 0)

        val move = graph.resolve(
            from = TvDetailFocusPosition.episodeGroup(index = 1),
            direction = TvDetailFocusDirection.Down,
        )

        assertThat(move.target).isEqualTo(TvDetailFocusPosition.episodeGroup(index = 1))
        assertThat(move.boundary).isTrue()
    }

    /**
     * 构造焦点图。
     *
     * @param sourceCount 线路数量。
     * @param currentSourceIndex 当前线路下标。
     * @param episodeCount 剧集数量。
     * @param currentEpisodeIndex 当前剧集下标。
     * @param recommendCount 推荐数量。
     * @return 详情页焦点图。
     */
    private fun focusGraph(
        sourceCount: Int,
        currentSourceIndex: Int = 0,
        episodeCount: Int,
        currentEpisodeIndex: Int = 0,
        recommendCount: Int = 1,
    ): TvDetailFocusGraph {
        return TvDetailFocusGraph(
            sourceCount = sourceCount,
            currentSourceIndex = currentSourceIndex,
            episodeCount = episodeCount,
            currentEpisodeIndex = currentEpisodeIndex,
            selectedEpisodeGroupIndex = currentEpisodeIndex / 20,
            recommendCount = recommendCount,
        )
    }
}
