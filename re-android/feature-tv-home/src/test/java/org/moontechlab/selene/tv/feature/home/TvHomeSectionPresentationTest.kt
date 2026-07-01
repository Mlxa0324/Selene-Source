package org.moontechlab.selene.tv.feature.home

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.moontechlab.selene.tv.core.data.model.TvHomeSection
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * 校验 TV 首页分区展示规则。
 */
class TvHomeSectionPresentationTest {
    /**
     * 首页横向分区应按 Flutter TV 的数量上限截断，并在溢出时展示更多入口。
     */
    @Test
    fun presentation_limitsVisibleVideosAndExposesMoreTargetWhenOverflow() {
        val section = TvHomeSection(
            key = "hot_movies",
            title = "热门电影",
            videos = videoCards(count = 18),
        )

        val presentation = section.toHomeSectionPresentation()

        assertThat(presentation.visibleVideos).hasSize(TV_HOME_MAX_VISIBLE_VIDEOS)
        assertThat(presentation.visibleVideos.last().id).isEqualTo("video-14")
        assertThat(presentation.showMore).isTrue()
        assertThat(presentation.moreTarget).isEqualTo(TvHomeSectionMoreTarget.Movie)
    }

    /**
     * 未超过首页展示上限时不展示更多入口，避免尾部多出无意义卡片。
     */
    @Test
    fun presentation_hidesMoreTargetWhenSectionDoesNotOverflow() {
        val section = TvHomeSection(
            key = "hot_tv_shows",
            title = "热门剧集",
            videos = videoCards(count = TV_HOME_MAX_VISIBLE_VIDEOS),
        )

        val presentation = section.toHomeSectionPresentation()

        assertThat(presentation.visibleVideos).hasSize(TV_HOME_MAX_VISIBLE_VIDEOS)
        assertThat(presentation.showMore).isFalse()
        assertThat(presentation.moreTarget).isNull()
    }

    /**
     * 首页更多入口应映射到现有顶层页面，保持与 Flutter TV 首页跳转语义一致。
     */
    @Test
    fun moreTarget_mapsHomeSectionsToTopLevelPages() {
        assertThat(homeSectionMoreTargetFor("continue_watching"))
            .isEqualTo(TvHomeSectionMoreTarget.History)
        assertThat(homeSectionMoreTargetFor("hot_movies"))
            .isEqualTo(TvHomeSectionMoreTarget.Movie)
        assertThat(homeSectionMoreTargetFor("hot_tv_shows"))
            .isEqualTo(TvHomeSectionMoreTarget.Tv)
        assertThat(homeSectionMoreTargetFor("bangumi_calendar"))
            .isEqualTo(TvHomeSectionMoreTarget.Anime)
        assertThat(homeSectionMoreTargetFor("hot_shows"))
            .isEqualTo(TvHomeSectionMoreTarget.Show)
        assertThat(homeSectionMoreTargetFor("favorites"))
            .isEqualTo(TvHomeSectionMoreTarget.Favorites)
    }

    /**
     * 首页内容焦点应跳过空分区，避免顶部向下时请求不存在的卡片焦点。
     */
    @Test
    fun firstFocusableHomeSectionIndex_skipsEmptySections() {
        val sections = listOf(
            TvHomeSection(
                key = "continue_watching",
                title = "继续观看",
                videos = emptyList(),
            ),
            TvHomeSection(
                key = "hot_movies",
                title = "热门电影",
                videos = videoCards(count = 2),
            ),
        )

        assertThat(firstFocusableHomeSectionIndex(sections)).isEqualTo(1)
    }

    /**
     * 首页没有任何卡片时不提供内容焦点目标。
     */
    @Test
    fun firstFocusableHomeSectionIndex_returnsNullWhenAllSectionsAreEmpty() {
        val sections = listOf(
            TvHomeSection(
                key = "continue_watching",
                title = "继续观看",
                videos = emptyList(),
            ),
        )

        assertThat(firstFocusableHomeSectionIndex(sections)).isNull()
    }

    /**
     * 构造指定数量的视频卡片测试数据。
     *
     * @param count 视频数量。
     * @return 视频卡片列表。
     */
    private fun videoCards(count: Int): List<TvVideoCard> {
        return List(count) { index ->
            TvVideoCard(
                id = "video-$index",
                title = "视频 $index",
                posterUrl = "",
            )
        }
    }
}
