package org.moontechlab.selene.tv.app.navigation

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import org.moontechlab.selene.tv.core.player.api.PlaybackRequest

/**
 * 校验详情页到播放器的播放请求暂存契约。
 */
class TvPlaybackRequestStoreTest {
    /**
     * 暂存器应使用短 ID 保存完整播放请求，避免把播放 URL 暴露到导航路由。
     */
    @Test
    fun save_and_get_keeps_complete_playback_request() {
        val store = TvPlaybackRequestStore()
        val request = PlaybackRequest(
            videoId = "video-1",
            sourceId = "source-a",
            episodeId = "ep-2",
            url = "https://cdn.test/video.m3u8?token=a&b=2",
            startPositionMs = 42_000L,
        )

        val requestId = store.save(request)

        assertThat(requestId).isNotEmpty()
        assertThat(requestId.contains(request.url)).isEqualTo(false)
        assertThat(store.get(requestId)).isEqualTo(request)
    }
}
