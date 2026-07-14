package org.moontechlab.selene.tv.core.network

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test

/**
 * 校验外部首字母联想解析与过滤规则，对齐 Flutter ExternalSearchSuggestionService。
 */
class ExternalSearchSuggestionServiceTest {
    /**
     * 仅纯字母数字查询才允许走外部联想。
     */
    @Test
    fun isInitialsQuery_only_accepts_letters_and_digits() {
        assertThat(ExternalSearchSuggestionService.isInitialsQuery("JL")).isTrue()
        assertThat(ExternalSearchSuggestionService.isInitialsQuery("ABC123")).isTrue()
        assertThat(ExternalSearchSuggestionService.isInitialsQuery("")).isFalse()
        assertThat(ExternalSearchSuggestionService.isInitialsQuery("剑来")).isFalse()
        assertThat(ExternalSearchSuggestionService.isInitialsQuery("J 来")).isFalse()
    }

    /**
     * 腾讯联想解析：去掉 em 标签，读取 lines[0].text。
     */
    @Test
    fun parseTencentBody_strips_em_and_reads_line_text() {
        val body = """
            {
              "data": {
                "result_list": {
                  "item_list": [
                    {"view":{"lines":[{"text":"<em>剑</em>来"}]}},
                    {"view":{"lines":[{"text":"  庆余年  "}]}},
                    {"view":{"lines":[]}}
                  ]
                }
              }
            }
        """.trimIndent()

        val result = ExternalSearchSuggestionService.parseTencentBody(body)

        assertThat(result).containsExactly("剑来", "庆余年").inOrder()
    }

    /**
     * 爱奇艺联想解析：读取 keyWordData[].name。
     */
    @Test
    fun parseIqiyiBody_reads_keyword_names() {
        val body = """
            {
              "data": {
                "keyWordData": [
                  {"name":"三体"},
                  {"name":"  "},
                  {"name":"繁花"}
                ]
              }
            }
        """.trimIndent()

        val result = ExternalSearchSuggestionService.parseIqiyiBody(body)

        assertThat(result).containsExactly("三体", "繁花").inOrder()
    }

    /**
     * 芒果联想解析：读取 suggest[].title。
     */
    @Test
    fun parseMgtvBody_reads_suggest_titles() {
        val body = """
            {
              "data": {
                "suggest": [
                  {"title":"狂飙"},
                  {"title":"漫长的季节"}
                ]
              }
            }
        """.trimIndent()

        val result = ExternalSearchSuggestionService.parseMgtvBody(body)

        assertThat(result).containsExactly("狂飙", "漫长的季节").inOrder()
    }

    /**
     * 去重保持首次出现顺序，并折叠空白。
     */
    @Test
    fun dedupeSuggestions_keeps_order_and_normalizes_spaces() {
        val result = ExternalSearchSuggestionService.dedupeSuggestions(
            listOf("剑  来", "剑 来", "庆余年", "剑 来", "  "),
        )

        assertThat(result).containsExactly("剑 来", "庆余年").inOrder()
    }

    /**
     * 非首字母查询直接返回空，不打外站。
     */
    @Test
    fun fetchSuggestions_returns_empty_for_chinese_query() = runTest {
        val service = ExternalSearchSuggestionService()
        val result = service.fetchSuggestions("剑来")
        assertThat(result).isEmpty()
    }
}
