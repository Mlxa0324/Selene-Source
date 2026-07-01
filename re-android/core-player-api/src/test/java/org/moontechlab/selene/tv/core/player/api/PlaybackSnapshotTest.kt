package org.moontechlab.selene.tv.core.player.api

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验播放器快照字段契约。
 */
class PlaybackSnapshotTest {
    /**
     * 快照需要完整保留切内核恢复所需的核心播放状态。
     */
    @Test
    fun snapshot_keeps_source_episode_position_speed_and_resize_mode() {
        val snapshot = PlaybackSnapshot(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-3",
            url = "https://cdn.test/3.m3u8",
            positionMs = 92_000L,
            durationMs = 1_800_000L,
            cachedRanges = listOf(
                PlaybackCachedRange(startMs = 90_000L, endMs = 180_000L),
            ),
            networkSpeedBytesPerSecond = 512_000L,
            playbackSpeed = 1.25f,
            resizeMode = TvResizeMode.FIT,
        )

        assertThat(snapshot.sourceId).isEqualTo("source-a")
        assertThat(snapshot.episodeId).isEqualTo("ep-3")
        assertThat(snapshot.positionMs).isEqualTo(92_000L)
        assertThat(snapshot.cachedRanges).containsExactly(
            PlaybackCachedRange(startMs = 90_000L, endMs = 180_000L),
        )
        assertThat(snapshot.networkSpeedBytesPerSecond).isEqualTo(512_000L)
        assertThat(snapshot.playbackSpeed).isEqualTo(1.25f)
        assertThat(snapshot.resizeMode).isEqualTo(TvResizeMode.FIT)
    }
}
