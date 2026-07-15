package org.moontechlab.selene.tv.core.design.layout

import com.google.common.truth.Truth.assertThat
import java.io.File
import org.junit.Test

/**
 * 校验共享选集连续横轨契约（详情 / 全屏播放器共用）。
 */
class TvEpisodePlaylistRailContractTest {
    @Test
    fun rail_uses_continuous_soft_edge_follow_and_group_confirm_semantics() {
        val source = File(
            "src/main/java/org/moontechlab/selene/tv/core/design/layout/TvEpisodePlaylistRail.kt",
        ).readText()

        assertThat(source).contains("fun TvEpisodePlaylistRail(")
        assertThat(source).contains("TvEpisodePlaylistPinMode.SoftEdgeFollow")
        assertThat(source).contains("TvEpisodePlaylistPinMode.PinLeading")
        assertThat(source).contains("LocalBringIntoViewSpec")
        assertThat(source).contains("moveHorizontalChipFocus")
        assertThat(source).contains("moveGroupFocus")
        assertThat(source).contains("moveEpisodeFocus")
        // 不按组拆页：全量 items(count = episodes.size)
        assertThat(source).contains("count = episodes.size")
        // 分组确认才改 selectedGroup；左右只 moveGroupFocus。
        assertThat(source).contains("selectedGroup = gi")
        assertThat(source).contains("moveGroupFocus(gi - 1)")
        assertThat(source).contains("moveGroupFocus(gi + 1)")
        assertThat(source).contains("TV_EPISODE_PLAYLIST_GROUP_SIZE")
        // 详情页无 pin 门票时，仍须把当前集滚入可视区（不抢焦点）。
        assertThat(source).contains("LaunchedEffect(currentAbsoluteIndex, episodes.size, currentEpisodeId)")
        assertThat(source).contains("仅滚动：不 requestFocus")
        assertThat(source).contains("scrollToItem(index = target)")
    }
}
