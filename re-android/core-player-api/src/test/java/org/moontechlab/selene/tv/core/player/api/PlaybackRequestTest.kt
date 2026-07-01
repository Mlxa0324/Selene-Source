package org.moontechlab.selene.tv.core.player.api

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验播放器加载请求的跨层字段契约。
 */
class PlaybackRequestTest {
    /**
     * 播放请求必须保留片名和集名，供弹幕手动匹配面板带入默认搜索词。
     */
    @Test
    fun playback_request_keeps_video_and_episode_titles_for_danmaku_match() {
        val request = PlaybackRequest(
            videoId = "video-1",
            videoTitle = "测试影片",
            sourceId = "source-a",
            episodeId = "ep-2",
            episodeIndex = 1,
            episodeTitle = "第 2 集",
            url = "https://cdn.test/2.m3u8",
        )

        assertThat(request.videoTitle).isEqualTo("测试影片")
        assertThat(request.episodeTitle).isEqualTo("第 2 集")
        assertThat(request.episodeIndex).isEqualTo(1)
    }
}
