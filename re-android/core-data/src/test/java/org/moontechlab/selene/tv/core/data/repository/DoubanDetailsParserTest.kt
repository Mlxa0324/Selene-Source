package org.moontechlab.selene.tv.core.data.repository

import com.google.common.truth.Truth.assertThat
import org.junit.Test

/**
 * 校验豆瓣详情页相关推荐 HTML 解析契约。
 */
class DoubanDetailsParserTest {
    /**
     * 推荐容器包含嵌套标签时，应完整解析多条推荐并兼容属性顺序、单双引号和可选评分。
     */
    @Test
    fun parseRecommends_parses_nested_container_and_supported_link_shapes() {
        val cards = DoubanDetailsParser.parseRecommends(RECOMMENDATION_HTML)

        assertThat(cards.map { card -> card.id })
            .containsExactly("1111111", "2222222")
            .inOrder()
        assertThat(cards.map { card -> card.title })
            .containsExactly("推荐甲", "推荐乙")
            .inOrder()
        assertThat(cards.map { card -> card.posterUrl })
            .containsExactly("https://img.test/a.jpg", "https://img.test/b.jpg")
            .inOrder()
        assertThat(cards.map { card -> card.doubanRate })
            .containsExactly("9.1", "")
            .inOrder()
        assertThat(cards.map { card -> card.source })
            .containsExactly("douban", "douban")
            .inOrder()
    }

    /**
     * 推荐容器缺失时，应返回空列表而不是误解析页面其它链接。
     */
    @Test
    fun parseRecommends_returns_empty_when_container_is_missing() {
        val html = """
            <div id="other-section">
              <dl>
                <dt><a href="/subject/3333333/"><img src="https://img.test/c.jpg" alt="非推荐"></a></dt>
              </dl>
            </div>
        """.trimIndent()

        assertThat(DoubanDetailsParser.parseRecommends(html)).isEmpty()
    }

    /**
     * 推荐容器没有匹配闭合标签时，应按非法内容返回空列表。
     */
    @Test
    fun parseRecommends_returns_empty_when_container_is_malformed() {
        val html = """
            <div id="recommendations">
              <div class="recommendations-bd">
                <dl>
                  <dt><a href="/subject/3333333/"><img src="https://img.test/c.jpg" alt="未闭合推荐"></a></dt>
                </dl>
        """.trimIndent()

        assertThat(DoubanDetailsParser.parseRecommends(html)).isEmpty()
    }

    /**
     * 缺少 ID、标题或海报的推荐项应分别跳过，不能影响后续完整条目。
     */
    @Test
    fun parseRecommends_skips_incomplete_items() {
        val html = """
            <div id="recommendations">
              <dl><dt><a href="/subject/4444444/"><img src="https://img.test/d.jpg" alt=""></a></dt></dl>
              <dl><dt><a href="/celebrity/5555555/"><img src="https://img.test/e.jpg" alt="缺少条目 ID"></a></dt></dl>
              <dl><dt><a href="/subject/6666666/"><img src="" alt="缺少海报"></a></dt></dl>
              <dl><dt><a href="https://movie.douban.com/subject/7777777/"><img alt="完整推荐" src="https://img.test/g.jpg"></a></dt></dl>
            </div>
        """.trimIndent()

        val cards = DoubanDetailsParser.parseRecommends(html)

        assertThat(cards).hasSize(1)
        assertThat(cards.single().id).isEqualTo("7777777")
        assertThat(cards.single().title).isEqualTo("完整推荐")
    }

    private companion object {
        /** 覆盖嵌套容器、协议相对地址、相对条目地址和属性乱序的推荐 HTML。 */
        val RECOMMENDATION_HTML = """
            <div class='aside' data-kind='movie' id='recommendations'>
              <div class="hd"><h2>喜欢这部电影的人也喜欢</h2></div>
              <div class="recommendations-bd">
                <dl>
                  <dt><a data-track="first" href="//movie.douban.com/subject/1111111/"><img alt="推荐甲" loading="lazy" src="//img.test/a.jpg"></a></dt>
                  <dd><span class="subject-rate">9.1</span></dd>
                </dl>
                <dl class='recommendation-item'>
                  <dt><a href='/subject/2222222/'><img src='https://img.test/b.jpg' data-size='large' alt='推荐乙'></a></dt>
                </dl>
              </div>
            </div>
        """.trimIndent()
    }
}
