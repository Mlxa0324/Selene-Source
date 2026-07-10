package org.moontechlab.selene.tv.core.data.repository

import org.moontechlab.selene.tv.core.data.model.DoubanRecommendItem
import org.moontechlab.selene.tv.core.data.model.TvVideoCard

/**
 * 豆瓣详情页 HTML 解析器。
 *
 * 从豆瓣影视详情页 HTML 中提取「相关推荐」区域，
 * 镜像 Flutter `_parseDoubanHtmlDetails` 推荐解析逻辑。
 */
object DoubanDetailsParser {

    /**
     * 从 HTML 中解析推荐条目并转为 [TvVideoCard] 列表。
     *
     * @param html 豆瓣详情页 HTML 正文。
     * @return 推荐影视卡片列表。
     */
    fun parseRecommends(html: String): List<TvVideoCard> {
        val items = parseRecommendItems(html)
        return items.map { it.toVideoCard() }
    }

    /**
     * 从 HTML 中解析推荐条目原始模型。
     *
     * @param html 豆瓣详情页 HTML 正文。
     * @return 推荐条目列表。
     */
    fun parseRecommendItems(html: String): List<DoubanRecommendItem> {
        val recommendations = mutableListOf<DoubanRecommendItem>()

        // 推荐容器可能包含多层 div，必须找到与起始标签匹配的完整内容。
        val containerContent = findRecommendationsContainer(html) ?: return emptyList()
        val dlMatches = DL_BLOCK_REGEX.findAll(containerContent)

        for (dlMatch in dlMatches) {
            val dlContent = dlMatch.groupValues.getOrElse(1) { "" }

            // 链接、图片和评分属性分别解析，避免依赖豆瓣页面属性顺序。
            val recommendId = ANCHOR_TAG_REGEX.findAll(dlContent)
                .mapNotNull { match -> readAttribute(match.value, "href")?.toDoubanSubjectIdOrNull() }
                .firstOrNull()
                ?: continue
            val imageTag = IMAGE_TAG_REGEX.find(dlContent)?.value ?: continue
            val posterUrl = readAttribute(imageTag, "src")
                ?.normalizePosterUrl()
                ?.takeIf { value -> value.isNotBlank() }
                ?: continue
            val title = readAttribute(imageTag, "alt")
                ?.trim()
                ?.takeIf { value -> value.isNotEmpty() }
                ?: continue
            val rate = SPAN_BLOCK_REGEX.findAll(dlContent)
                .firstOrNull { match ->
                    readAttribute(match.groupValues.getOrElse(1) { "" }, "class")
                        ?.split(Regex("""\s+"""))
                        ?.any { className -> className.equals("subject-rate", ignoreCase = true) } == true
                }
                ?.groupValues
                ?.getOrNull(2)
                ?.trim()
                ?.takeIf { value -> value.isNotEmpty() }

            recommendations.add(
                DoubanRecommendItem(
                    id = recommendId,
                    title = title,
                    poster = posterUrl,
                    rate = rate,
                ),
            )
        }

        return recommendations
    }

    /**
     * 查找完整的相关推荐容器正文。
     *
     * @param html 豆瓣详情页 HTML。
     * @return 容器正文；容器缺失或标签不平衡时返回空。
     */
    private fun findRecommendationsContainer(html: String): String? {
        val openingTag = DIV_TAG_REGEX.findAll(html)
            .firstOrNull { match ->
                !match.value.startsWith("</", ignoreCase = true) &&
                    readAttribute(match.value, "id").equals("recommendations", ignoreCase = true)
            }
            ?: return null
        val bodyStart = openingTag.range.last + 1
        var depth = 1

        // 从推荐容器起始标签后扫描同类标签，深度归零才算匹配闭合。
        for (match in DIV_TAG_REGEX.findAll(html, bodyStart)) {
            if (match.value.startsWith("</", ignoreCase = true)) {
                depth -= 1
                if (depth == 0) {
                    return html.substring(bodyStart, match.range.first)
                }
            } else {
                depth += 1
            }
        }
        return null
    }

    /**
     * 读取 HTML 标签中的指定属性。
     *
     * @param tag 单个 HTML 标签文本。
     * @param name 属性名称。
     * @return 属性值；属性不存在时返回空。
     */
    private fun readAttribute(
        tag: String,
        name: String,
    ): String? {
        val attributeRegex = Regex(
            pattern = """\b${Regex.escape(name)}\s*=\s*[\"']([^\"']*)[\"']""",
            option = RegexOption.IGNORE_CASE,
        )
        return attributeRegex.find(tag)?.groupValues?.getOrNull(1)
    }

    /**
     * 从受支持的豆瓣条目链接中提取 ID。
     *
     * @return 豆瓣条目 ID；链接格式不受支持时返回空。
     */
    private fun String.toDoubanSubjectIdOrNull(): String? {
        val href = trim()
        return DOUBAN_SUBJECT_LINK_REGEX.find(href)
            ?.groupValues
            ?.drop(1)
            ?.firstOrNull { value -> value.isNotEmpty() }
    }

    /**
     * 规范化推荐海报地址。
     *
     * @return 协议相对地址补齐 HTTPS 后的海报地址。
     */
    private fun String.normalizePosterUrl(): String {
        val posterUrl = trim()
        return if (posterUrl.startsWith("//")) {
            "https:$posterUrl"
        } else {
            posterUrl
        }
    }

    private fun DoubanRecommendItem.toVideoCard(): TvVideoCard {
        return TvVideoCard(
            id = id,
            source = "douban",
            title = title,
            posterUrl = poster,
            doubanRate = rate.orEmpty(),
        )
    }

    /** HTML 标签解析常量。 */
    private val DIV_TAG_REGEX = Regex("""</?div\b[^>]*>""", RegexOption.IGNORE_CASE)

    /** 推荐条目块解析常量。 */
    private val DL_BLOCK_REGEX = Regex(
        """<dl\b[^>]*>(.*?)</dl\s*>""",
        setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
    )

    /** 链接标签解析常量。 */
    private val ANCHOR_TAG_REGEX = Regex("""<a\b[^>]*>""", RegexOption.IGNORE_CASE)

    /** 图片标签解析常量。 */
    private val IMAGE_TAG_REGEX = Regex("""<img\b[^>]*>""", RegexOption.IGNORE_CASE)

    /** 文本标签解析常量。 */
    private val SPAN_BLOCK_REGEX = Regex(
        """<span\b([^>]*)>(.*?)</span\s*>""",
        setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL),
    )

    /** 豆瓣绝对、协议相对和站内相对条目链接解析常量。 */
    private val DOUBAN_SUBJECT_LINK_REGEX = Regex(
        """^(?:(?:https?:)?//movie\.douban\.com)?/subject/(\d+)(?:/|$)|^/subject/(\d+)(?:/|$)""",
        RegexOption.IGNORE_CASE,
    )
}
