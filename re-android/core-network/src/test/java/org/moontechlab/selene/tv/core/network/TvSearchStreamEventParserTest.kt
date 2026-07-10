package org.moontechlab.selene.tv.core.network

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验 TV 搜索 SSE 事件解析器。
 */
class TvSearchStreamEventParserTest {
    /**
     * `source_result` 事件必须把结果批次完整映射成 Kotlin 搜索结果模型。
     */
    @Test
    fun parse_maps_source_result_event_with_results() {
        val payload = """
            {
              "type": "source_result",
              "source": "source-a",
              "sourceName": "线路 A",
              "timestamp": 1720000000123,
              "results": [
                {
                  "id": "video-1",
                  "title": "测试影片",
                  "poster": "https://img.test/poster.jpg",
                  "episodes": ["https://cdn.test/1.m3u8"],
                  "episodes_titles": ["正片"],
                  "source": "source-a",
                  "source_name": "线路 A",
                  "year": "2026",
                  "desc": "剧情简介",
                  "douban_id": 12345
                }
              ]
            }
        """.trimIndent()

        val event = TvSearchStreamEventParser().parse(payload) as TvSearchSourceResultEvent

        assertThat(event.source).isEqualTo("source-a")
        assertThat(event.sourceName).isEqualTo("线路 A")
        assertThat(event.timestamp).isEqualTo(1720000000123)
        assertThat(event.results).hasSize(1)
        assertThat(event.results.first().id).isEqualTo("video-1")
        assertThat(event.results.first().sourceName).isEqualTo("线路 A")
        assertThat(event.results.first().episodeTitles).containsExactly("正片")
        assertThat(event.results.first().doubanId).isEqualTo(12345)
    }

    /**
     * 未知事件类型必须显式报错，避免静默吞掉后导致详情页补源永远不结束。
     */
    @Test
    fun parse_throws_for_unknown_event_type() {
        val error = runCatching {
            TvSearchStreamEventParser().parse("""{"type":"unknown"}""")
        }.exceptionOrNull()

        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)
        assertThat(error?.message).contains("未知 TV 搜索 SSE 事件类型")
    }
}
