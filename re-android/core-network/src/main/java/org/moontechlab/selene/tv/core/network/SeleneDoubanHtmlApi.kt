package org.moontechlab.selene.tv.core.network

import kotlinx.coroutines.CancellationException

/**
 * 豆瓣详情页 HTML 数据源。
 */
fun interface DoubanSubjectHtmlSource {
    /**
     * 抓取指定豆瓣条目的详情页 HTML。
     *
     * @param doubanId 豆瓣条目 ID。
     * @return 豆瓣详情页 HTML 正文。
     */
    suspend fun fetchSubjectHtml(doubanId: String): String
}

/**
 * 豆瓣页面 HTML 抓取接口。
 *
 * 使用 OkHttp 直连豆瓣页面（非 Retrofit），
 * 通过 [DoubanVerifyService] 绕过 PoW 验证挑战。
 *
 * @property verifyService PoW 验证绕过服务。
 * @property cdnMirror CDN 镜像基地址（可选，不走 PoW）。
 */
class SeleneDoubanHtmlApi(
    private val verifyService: DoubanVerifyService,
    private val cdnMirror: String = CDN_MIRROR_TENCENT,
) : DoubanSubjectHtmlSource {
    /**
     * 抓取豆瓣影视详情页 HTML。
     *
     * @param doubanId 豆瓣条目 ID。
     * @return 页面 HTML 正文。
     */
    override suspend fun fetchSubjectHtml(doubanId: String): String {
        // 优先直连豆瓣（CDN 镜像服务的是 API 接口，不一定支持 /subject 页面 HTML）。
        return try {
            verifyService.fetchWithVerify("$DOUBAN_DIRECT/subject/$doubanId")
        } catch (cancellation: CancellationException) {
            // 页面切换或任务释放产生的取消必须立即传播，不能继续发起镜像请求。
            throw cancellation
        } catch (_: Exception) {
            // 直连失败回退到 CDN 镜像。
            verifyService.fetchWithVerify("$cdnMirror/subject/$doubanId")
        }
    }

    companion object {
        /** 豆瓣直连基地址。 */
        private const val DOUBAN_DIRECT = "https://movie.douban.com"

        /** 腾讯 CDN 镜像基地址（对齐 Flutter cdn_tencent）。 */
        private const val CDN_MIRROR_TENCENT = "https://movie.douban.cmliussss.net"
    }
}
